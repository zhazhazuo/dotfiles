#!/usr/bin/env bash
#
# tests/session-toggle.test.sh — the key that returns to the previous session
#
# The key keeps its pair in the config's Lua state, and a press takes the session it
# was pressed in from the calling context, so `rex do -s SESSION` stands in for a
# key press in that session. The key also asks the app to show the session it chose,
# so the test puts the app back on the session it found.
#
# The cases follow the report that started this: the pair alternates, a session
# chosen by hand returns to the session the key last sent you to, and pressing again
# from there returns to the session chosen by hand.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v rex >/dev/null 2>&1; then
	printf 'not ok - the rex CLI is not on PATH, so the key cannot be driven\n' >&2
	exit 1
fi

# `rex actions` may end on a broken pipe, and pipefail would fail the pipeline, so
# its output is captured first.
listed=no
for _ in 1 2 3 4 5; do
	actions=$(rex actions 2>/dev/null || true)
	if printf '%s\n' "$actions" | grep -q '^session_toggle_recent '; then
		listed=yes
		break
	fi
	sleep 0.5
done
if [[ "$listed" == no ]]; then
	printf 'not ok - the running Rex config defines no session_toggle_recent action\n' >&2
	exit 1
fi

app=$(rex client list --json 2>/dev/null | jq -r '.clients[] | select(.info.kind == "app") | .client_id' | head -1)
if [[ -z "$app" ]]; then
	printf 'not ok - the Rex app is not connected\n' >&2
	exit 1
fi

shown_session() {
	python3 - "$HOME/Library/Preferences/com.superlogical.rex.plist" <<'PY'
import re, sys
raw = open(sys.argv[1], "rb").read()
match = re.search(rb'\{"sessionID":"(session:[^"]+)"\}', raw)
print(match.group(1).decode() if match else "")
PY
}

original=$(shown_session)

cleanup() {
	if [[ -n "$original" ]]; then
		rex api call client.perform \
			"{\"client_id\":\"$app\",\"action\":\"session.select\",\"args\":{\"session_id\":\"$original\"},\"session_id\":\"$original\",\"origin\":\"key\"}" \
			>/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

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

# A press in SESSION, as the key would see it, and the session it chose.
press() {
	rex do -s "$1" session_toggle_recent 2>/dev/null | jq -r '.session_id // ""'
}

sessions=$(rex api call session.list | jq -r '.sessions[].session_id')
count=$(printf '%s\n' "$sessions" | grep -c . || true)
if [[ "$count" -lt 3 ]]; then
	printf 'not ok - the test needs three sessions, found %s\n' "$count" >&2
	exit 1
fi
first=$(printf '%s\n' "$sessions" | sed -n 1p)
second=$(printf '%s\n' "$sessions" | sed -n 2p)
third=$(printf '%s\n' "$sessions" | sed -n 3p)

# ── The pair alternates ───────────────────────────────────────────────────
away=$(press "$first")
if [[ -n "$away" && "$away" != "$first" ]]; then
	printf 'ok - the first press leaves the session it was pressed in\n'
else
	printf 'not ok - the first press leaves the session it was pressed in\n  chose: %s\n' "$away" >&2
	failures=$((failures + 1))
fi

assert_equal "$first" "$(press "$away")" "the next press returns to the first session"
assert_equal "$away" "$(press "$first")" "the press after that returns to the pair's other half"

# ── A session chosen by hand goes back to the last session the key sent you to ──

sent=$(press "$first")
by_hand=""
for candidate in $(printf '%s\n' "$sessions"); do
	if [[ "$candidate" != "$sent" ]]; then
		by_hand="$candidate"
		break
	fi
done
if [[ -z "$by_hand" ]]; then
	printf 'not ok - no session other than the chosen one to switch to by hand\n' >&2
	failures=$((failures + 1))
else
	assert_equal "$sent" "$(press "$by_hand")" "a session chosen by hand returns to the last session the key chose"
	assert_equal "$by_hand" "$(press "$sent")" "pressing again returns to the session chosen by hand"
fi

if ((failures > 0)); then
	printf '%d failure(s)\n' "$failures" >&2
	exit 1
fi
printf 'all session toggle tests passed\n'
