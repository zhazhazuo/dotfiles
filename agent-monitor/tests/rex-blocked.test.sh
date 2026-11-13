#!/usr/bin/env bash
#
# tests/rex-blocked.test.sh — the red needs-help state, both halves of the chain
#
# A red item needs two things, and the failure mode when one is missing is a
# bar that stays green through a question:
#
#   1. The program reports `blocked` over OSC 7501. pi raises that report only
#      for a UI component that declares one, so the questionnaire extension
#      carries a local patch (pi/patches/). Without it a waiting
#      `ask_user_question` leaves pi `working`.
#   2. agent-monitor maps `blocked` to needs-help.
#
# The first half is checked against the installed package. The second half runs
# against a live Rex block that prints the escape sequence itself, so it does not
# wait on a person or a model. It needs the Rex server, and skips without one.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADAPTER="$ROOT_DIR/adapters/rex.sh"
BIN="$ROOT_DIR/bin/agent-monitor"
PACKAGE="$HOME/.pi/agent/npm/node_modules/@juicesharp/rpiv-ask-user-question/ask-user-question.ts"

TMP_DIR="$(mktemp -d)"
export AGENT_MONITOR_STATE_DIR="$TMP_DIR/state"
mkdir -p "$AGENT_MONITOR_STATE_DIR"
# Keep the test off the live listing and the live app preferences.
export REX_LISTING="$TMP_DIR/no-listing.json"
export REX_SHOWN_FILE="$TMP_DIR/shown"
: >"$REX_SHOWN_FILE"

session_id=""
failures=0

cleanup() {
	[[ -n "$session_id" ]] && rex session kill "$session_id" >/dev/null 2>&1 || true
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_equal() {
	local expected="$1" actual="$2" name="$3"
	if [[ "$actual" != "$expected" ]]; then
		printf 'not ok - %s\n  expected: %s\n  actual:   %s\n' "$name" "$expected" "$actual" >&2
		failures=$((failures + 1))
		return 1
	fi
	printf 'ok - %s\n' "$name"
}

# ── The report pi must send ─────────────────────────────────────────────────

if [[ -f "$PACKAGE" ]]; then
	reports=$(grep -c "blocked: blockedOnQuestion(config)" "$PACKAGE" || true)
	assert_equal "2" "$reports" \
		"the questionnaire declares blocked on both mounts (pi/patches/apply.sh)" || true
else
	printf 'ok - questionnaire not installed, report half skipped\n'
fi

# ── The state agent-monitor must derive ─────────────────────────────────────

command -v rex >/dev/null 2>&1 || {
	printf 'ok - rex not available, live half skipped\n'
	exit "$failures"
}

created=$(rex new AGENT-MONITOR-BLOCKED-PROBE --json 2>/dev/null) || {
	printf 'ok - rex server not reachable, live half skipped\n'
	exit "$failures"
}
session_id=$(printf '%s' "$created" | jq -r '.session_id // empty')
[[ -n "$session_id" ]] || {
	printf 'not ok - the probe session reported no id\n' >&2
	exit 1
}

# The block reports blocked the way a program does, then waits. Nothing else
# touches it, so the state came from this report alone. `run` opens its own tab,
# so the block to watch is the one it returns, not the session's first block.
block_id=$(rex run -s "$session_id" --focus=false --json -- sh -c \
	'printf "\033]7501;state=blocked:app=probe:kind=question:msg=cGljayBvbmU=\033\\"; sleep 30' 2>/dev/null |
	jq -r '.block_ids[0] // empty' 2>/dev/null || true)
[[ -n "$block_id" ]] || {
	printf 'not ok - the probe program opened no block\n' >&2
	exit 1
}

reported=""
for _ in $(seq 1 20); do
	reported=$(rex api call -s "$session_id" com.superlogical.terminal.program_status \
		"$(jq -nc --arg b "$block_id" '{block_id: $b}')" 2>/dev/null |
		jq -r '.records[0].state // empty' 2>/dev/null || true)
	[[ "$reported" == "blocked" ]] && break
	sleep 0.5
done
assert_equal "blocked" "$reported" "rex records the blocked report" || true

"$ADAPTER" --sync >/dev/null 2>&1 || true

id=$(printf '%s' "$block_id" | tr -c '[:alnum:]_' '_')
state=$("$BIN" state --json 2>/dev/null | jq -r --arg id "$id" '.agents[$id].state // "-"')
assert_equal "needs-help" "$state" "a blocked report becomes needs-help" || true

if [[ "$failures" -gt 0 ]]; then
	printf '\n%s failure(s)\n' "$failures" >&2
	exit 1
fi
printf '\nall rex blocked tests passed\n'
