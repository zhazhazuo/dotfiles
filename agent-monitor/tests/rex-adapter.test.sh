#!/usr/bin/env bash
#
# tests/rex-adapter.test.sh — Rex source adapter
#
# Rex publishes program status per block, so the adapter is exercised through a
# fake `rex` that answers the three calls it makes: session.list, session.view,
# and com.superlogical.terminal.program_status. Events are fed the way
# `rex events --all --json` prints them, one compact JSON object per line.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADAPTER="$ROOT_DIR/adapters/rex.sh"
BIN="$ROOT_DIR/bin/agent-monitor"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export AGENT_MONITOR_STATE_DIR="$TMP_DIR/state"
export REX_FIXTURES="$TMP_DIR/fixtures"
export REX_EVENTS="$TMP_DIR/events.jsonl"
export REX_CALL_LOG="$TMP_DIR/rex-calls.log"
# No listing daemon in the test: the adapter must fall back to the CLI.
export REX_LISTING="$TMP_DIR/no-listing.json"
export REX_SHOWN_FILE="$TMP_DIR/shown"
mkdir -p "$REX_FIXTURES" "$AGENT_MONITOR_STATE_DIR"
: >"$REX_SHOWN_FILE"
: >"$REX_CALL_LOG"

failures=0
assert_equal() {
	local expected="$1" actual="$2" name="$3"
	if [[ "$actual" != "$expected" ]]; then
		printf 'not ok - %s\n  expected: %s\n  actual:   %s\n' "$name" "$expected" "$actual" >&2
		failures=$((failures + 1))
		return 1
	fi
	printf 'ok - %s\n' "$name"
}

mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/rex" <<'FAKE'
#!/usr/bin/env bash
# Minimal stand-in for the rex CLI.
set -euo pipefail
printf '%s\n' "$*" >>"${REX_CALL_LOG:?}"

case "${1:-}" in
ls)
	cat "${REX_FIXTURES}/sessions.json"
	;;
api)
	shift
	[[ "${1:-}" == "call" ]] || exit 1
	shift
	session=""
	if [[ "${1:-}" == "-s" ]]; then
		session="$2"
		shift 2
	fi
	method="${1:-}"
	shift || true
	case "$method" in
	session.list)
		cat "${REX_FIXTURES}/sessions.json"
		;;
	session.view)
		cat "${REX_FIXTURES}/view-${session}.json"
		;;
	com.superlogical.terminal.program_status)
		block=$(printf '%s' "${1:-}" | jq -r '.block_id')
		cat "${REX_FIXTURES}/status-${block}.json"
		;;
	com.superlogical.terminal.title)
		block=$(printf '%s' "${1:-}" | jq -r '.block_id')
		title_fixture="${REX_FIXTURES}/title-${block/:/_}.json"
		if [[ -f "$title_fixture" ]]; then
			cat "$title_fixture"
		else
			printf '{}\n'
		fi
		;;
	*)
		exit 1
		;;
	esac
	;;
events)
	cat "${REX_EVENTS}"
	;;
*)
	exit 1
	;;
esac
FAKE
chmod +x "$TMP_DIR/bin/rex"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"${NOTIFY_LOG:?}"\n' >"$TMP_DIR/bin/osascript"
chmod +x "$TMP_DIR/bin/osascript"
export NOTIFY_LOG="$TMP_DIR/notify.log"
export AGENT_MONITOR_FRONT_APP="Safari"
: >"$NOTIFY_LOG"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_DIR/bin/sketchybar"
chmod +x "$TMP_DIR/bin/sketchybar"
export PATH="$TMP_DIR/bin:$PATH"

# ── Fixtures ────────────────────────────────────────────────────────────────

cat >"${REX_FIXTURES}/sessions.json" <<'JSON'
{"sessions":[{"session_id":"session:1","label":"PLAYGROUND"},
             {"session_id":"session:2","label":"DOMAIN-WIKI"}]}
JSON

cat >"${REX_FIXTURES}/view-session:1.json" <<'JSON'
{"windows":[
 {"window_id":"window:1","label":"Window 1","layers":[{"blocks":[
   {"block_id":"block:a","label":"shell"},
   {"block_id":"block:b","label":"shell"}]}]},
 {"window_id":"window:2","label":"Window 2","layers":[{"blocks":[
   {"block_id":"block:c","label":"logs"}]}]}]}
JSON

cat >"${REX_FIXTURES}/view-session:2.json" <<'JSON'
{"windows":[
 {"window_id":"window:3","label":"Window 3","layers":[{"blocks":[
   {"block_id":"block:d","label":"shell"},
   {"block_id":"block:e","label":"shell"},
   {"block_id":"block:f","label":"shell"},
   {"block_id":"block:g","label":"shell"},
   {"block_id":"block:h","label":"shell"}]}]}]}
JSON

printf '%s\n' '{"records":[{"state":"working","app":"pi","id":""}]}' >"${REX_FIXTURES}/status-block:a.json"
printf '%s\n' '{"records":[{"state":"blocked","app":"pi","id":"","msg":"Approve 3 to add?"}]}' >"${REX_FIXTURES}/status-block:b.json"
printf '%s\n' '{"records":[{"state":"done","app":"pi","id":"","msg":"3 subagents (a, b, c)"}]}' >"${REX_FIXTURES}/status-block:c.json"
printf '%s\n' '{"records":[]}' >"${REX_FIXTURES}/status-block:d.json"
printf '%s\n' '{"records":[{"state":"idle","app":"pi","id":""}]}' >"${REX_FIXTURES}/status-block:e.json"
printf '%s\n' '{"records":[{"state":"error","app":"pi","id":"","msg":"exit 1"}]}' >"${REX_FIXTURES}/status-block:f.json"

# A parked block is only SubagentsRunning when its title says threads still run.
printf '%s\n' '{"records":[{"state":"done","app":"pi","id":"","msg":"Downloads"}]}' >"${REX_FIXTURES}/status-block:g.json"
printf '%s\n' '{"records":[{"state":"done","app":"pi","id":"","msg":"Downloads"}]}' >"${REX_FIXTURES}/status-block:h.json"
printf '%s\n' '{"title":"π - Downloads"}' >"${REX_FIXTURES}/title-block_g.json"
printf '%s\n' '{"title":"⏳ 2 subagents (alpha, beta) · 1:05"}' >"${REX_FIXTURES}/title-block_h.json"
# A working block keeps its own state even while its threads run.
printf '%s\n' '{"title":"⏳ 1 subagent (solo) · 0:30"}' >"${REX_FIXTURES}/title-block_a.json"

# ── Sync ────────────────────────────────────────────────────────────────────

# A stale rex entry, which sync must drop.
"$BIN" reconcile rex RunStart '{"pane_id":"block:zzz","label":"OLD"}' >/dev/null

"$ADAPTER" --sync

actual=$("$BIN" state --json | jq -r '.agents | to_entries | sort_by(.key) | .[] | "\(.key) \(.value.state) \(.value.label // "-") \(.value.pane)"')
expected=$'block_a running PLAYGROUND block:a\nblock_b needs-help PLAYGROUND block:b\nblock_c subagents-running PLAYGROUND block:c\nblock_e idle DOMAIN-WIKI block:e\nblock_f needs-attention DOMAIN-WIKI block:f\nblock_g needs-attention DOMAIN-WIKI block:g\nblock_h subagents-running DOMAIN-WIKI block:h'
assert_equal "$expected" "$actual" "sync maps working, blocked, done+subagents, idle, error, and title subagents" || true

if [[ -s "$NOTIFY_LOG" ]]; then
	printf 'not ok - the bridge must not send its own notification\n' >&2
	failures=$((failures + 1))
else
	printf 'ok - the bridge sends no notification of its own\n'
fi

removed=$("$BIN" state --json | jq -r '(.agents | has("block_zzz")) | tostring')
assert_equal "false" "$removed" "sync drops a stale rex entry" || true

# ── Watch ───────────────────────────────────────────────────────────────────

cat >"$REX_EVENTS" <<'JSONL'
{"type":"session_event","payload":{"session_id":"session:1","event":{"type":"block_event","payload":{"block_id":"block:x","name":"program_status_changed","payload":{"record":{"state":"working","app":"pi"}}}}}}
{"type":"session_event","payload":{"session_id":"session:1","event":{"type":"block_event","payload":{"block_id":"block:x","name":"program_status_changed","payload":{"record":{"state":"blocked","app":"pi","msg":"Pick one"}}}}}}
{"type":"session_event","payload":{"session_id":"session:1","event":{"type":"block_event","payload":{"block_id":"block:y","name":"program_status_changed","payload":{"record":{"state":"done","app":"pi"}}}}}}
{"type":"session_event","payload":{"session_id":"session:1","event":{"type":"block_event","payload":{"block_id":"block:y","name":"block_closed","payload":{}}}}}
JSONL

"$ADAPTER" --watch

watched=$("$BIN" state --json | jq -r '.agents["block_x"].state // "-"')
assert_equal "needs-help" "$watched" "watch follows a status change to blocked" || true

gone=$("$BIN" state --json | jq -r '(.agents | has("block_y")) | tostring')
assert_equal "false" "$gone" "block_closed drops the entry" || true

# x was reported and then removed by program_status_removed; y by block_closed.
# Re-run with an explicit removal line to prove program_status_removed too.
cat >"$REX_EVENTS" <<'JSONL'
{"type":"session_event","payload":{"session_id":"session:1","event":{"type":"block_event","payload":{"block_id":"block:z","name":"program_status_changed","payload":{"record":{"state":"working","app":"pi"}}}}}}
{"type":"session_event","payload":{"session_id":"session:1","event":{"type":"block_event","payload":{"block_id":"block:z","name":"program_status_removed","payload":{"reason":"exit"}}}}}
JSONL
"$ADAPTER" --watch
leftover=$("$BIN" state --json | jq -r '.agents | has("block_z") | tostring')
assert_equal "false" "$leftover" "program_status_removed drops the entry" || true

# The subagent bridge rewrites the title while threads run; that is the signal.
printf '%s\n' '{"records":[{"state":"done","app":"pi","id":"","msg":"Downloads"}]}' >"${REX_FIXTURES}/status-block:w.json"
printf '%s\n' '{"title":"⏳ 1 subagent (solo) · 0:10"}' >"${REX_FIXTURES}/title-block_w.json"
cat >"$REX_EVENTS" <<'JSONL'
{"type":"session_event","payload":{"session_id":"session:1","event":{"type":"block_event","payload":{"block_id":"block:w","name":"program_status_changed","payload":{"record":{"state":"done","app":"pi"}}}}}}
{"type":"session_event","payload":{"session_id":"session:1","event":{"type":"block_event","payload":{"block_id":"block:w","name":"title_changed","payload":{"title":"⏳ 1 subagent (solo) · 0:10"}}}}}
JSONL
"$ADAPTER" --watch
titled=$("$BIN" state --json | jq -r '.agents["block_w"].state // "-"')
assert_equal "subagents-running" "$titled" "a title change on a parked block reports subagents" || true

# ── Listing Source ─────────────────────────────────────────────────────────
# The daemon's listing answers state and focus in one read. No CLI process is
# asked for session.list, session.view, or program_status while it is fresh. A
# parked block still asks for its title, because the subagent count lives there.
cat >"$TMP_DIR/listing.json" <<'JSON'
{"generated_at":1700000000,"sessions":[
 {"session_id":"session:L","label":"LISTED","windows":[
   {"window_id":"window:1","label":"Tab","active":true,"blocks":[
     {"block_id":"block:p","focused":true,"state":"done","message":"3 subagents (a, b, c)","updated_at":"2026-11-13T11:00:00+08:00"},
     {"block_id":"block:q","focused":false,"state":"done","message":"review me","updated_at":"2026-11-13T11:00:00+08:00"}]},
   {"window_id":"window:3","label":"Hidden tab","active":false,"blocks":[
     {"block_id":"block:t","focused":true,"state":"done","message":"review me","updated_at":"2026-11-13T11:00:00+08:00"}]}]},
 {"session_id":"session:M","label":"HIDDEN","windows":[
   {"window_id":"window:2","label":"Tab","active":true,"blocks":[
     {"block_id":"block:r","focused":true,"state":"done","message":"review me","updated_at":"2026-11-13T11:00:00+08:00"},
     {"block_id":"block:s","focused":false,"state":"working","message":"build","updated_at":"2026-11-13T11:00:00+08:00"}]}]}]}
JSON
printf '%s\n' "session:L" >"$REX_SHOWN_FILE"
date +%s >"$TMP_DIR/listing.json.alive"
export REX_LISTING="$TMP_DIR/listing.json"
: >"$REX_CALL_LOG"

"$ADAPTER" --sync

actual=$("$BIN" state --tsv | awk -F'\t' 'NR > 1 {print $1, $3, $8}' | sort)
expected=$'block_p subagents-running 0\nblock_q needs-attention 0\nblock_r needs-attention 0\nblock_s running 0\nblock_t needs-attention 0'
assert_equal "$expected" "$actual" "the listing maps state and leaves every unseen run unseen" || true

api_calls=$(grep -cE 'session\.list|session\.view|program_status' "$REX_CALL_LOG" || true)
assert_equal "0" "$api_calls" "a fresh listing needs no session or status call" || true

# The shown session's focused pane is what counts as looked at.
printf '%s\n' "session:M" >"$REX_SHOWN_FILE"
"$ADAPTER" --sync
seen=$("$BIN" state --tsv | awk -F'\t' 'NR > 1 && $1 == "block_r" {print $8}')
assert_equal "1" "$seen" "a focused run in the shown session is seen" || true
unseen=$("$BIN" state --tsv | awk -F'\t' 'NR > 1 && $1 == "block_p" {print $8}')
assert_equal "0" "$unseen" "a run with subagents still working is not seen" || true

hidden_tab=$("$BIN" state --tsv | awk -F'\t' 'NR > 1 && $1 == "block_t" {print $8}')
assert_equal "0" "$hidden_tab" "a focused pane in a hidden tab is not seen" || true

# Focus moving to a settled pane marks it seen, with no state change.
printf '%s\n' "session:L" >"$REX_SHOWN_FILE"
sed 's/"block:q","focused":false/"block:q","focused":true/' \
	"$TMP_DIR/listing.json" >"$TMP_DIR/listing.next" && mv "$TMP_DIR/listing.next" "$TMP_DIR/listing.json"
cat >"$REX_EVENTS" <<'JSONL'
{"type":"session_event","payload":{"session_id":"session:L","event":{"type":"session_view_changed","payload":{"revision":12}}}}
JSONL
"$ADAPTER" --watch
focused_seen=$("$BIN" state --tsv | awk -F'\t' 'NR > 1 && $1 == "block_q" {print $8 " " $3}')
assert_equal "1 needs-attention" "$focused_seen" "a focus event marks the settled pane seen without changing state" || true

# A new run clears the mark, so the next finish asks again.
cat >"$REX_EVENTS" <<'JSONL'
{"type":"session_event","payload":{"session_id":"session:L","event":{"type":"block_event","payload":{"block_id":"block:q","name":"program_status_changed","payload":{"record":{"state":"working","app":"pi"}}}}}}
JSONL
"$ADAPTER" --watch
cleared=$("$BIN" state --tsv | awk -F'\t' 'NR > 1 && $1 == "block_q" {print $8 " " $3}')
assert_equal "0 running" "$cleared" "a new run clears the seen mark" || true

if [[ "$failures" -gt 0 ]]; then
	printf '\n%s failure(s)\n' "$failures" >&2
	exit 1
fi
printf '\nall rex adapter tests passed\n'
