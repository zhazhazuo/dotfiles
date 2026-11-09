#!/usr/bin/env bash
#
# tests/golden-ratio-toggle.test.sh — the command that turns the resize on and off
#
# The command drives launchd, so a fake proves nothing: the test unloads the real
# job and checks that a focus change stops moving the split, then loads it again
# and checks that the split moves. Each case gets a throwaway session with two
# panes, and the caller's focused pane is taken back at the end.
#
# The job is left as it was found. Turning it off here turns it off for the live
# windows too, which is why the trap restores it.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND="$ROOT_DIR/bin/golden-ratio"
label="local.rex-golden-ratio"
domain="gui/$(id -u)"

if ! command -v rex >/dev/null 2>&1; then
	printf 'not ok - the rex CLI is not on PATH, so the split cannot be driven\n' >&2
	exit 1
fi
if [[ ! -x "$COMMAND" ]]; then
	printf 'not ok - %s is not executable\n' "$COMMAND" >&2
	exit 1
fi

was_on=no
if launchctl print "$domain/$label" >/dev/null 2>&1; then was_on=yes; fi

sessions=()
cleanup() {
	local s
	for s in "${sessions[@]:-}"; do
		[[ -n "$s" ]] && rex kill "$s" >/dev/null 2>&1
	done
	if [[ "$was_on" == yes ]]; then
		"$COMMAND" on >/dev/null 2>&1 || true
	fi
	if [[ -n "${REX_BLOCK:-}" && -n "${REX_SESSION:-}" ]]; then
		rex api call session.focus_block \
			"{\"session_id\":\"$REX_SESSION\",\"block_id\":\"$REX_BLOCK\"}" >/dev/null 2>&1
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

assert_contains() {
	local needle="$1" haystack="$2" name="$3"
	if [[ "$haystack" != *"$needle"* ]]; then
		printf 'not ok - %s\n  missing: %s\n  in:      %s\n' "$name" "$needle" "$haystack" >&2
		failures=$((failures + 1))
		return 1
	fi
	printf 'ok - %s\n' "$name"
}

loaded() { launchctl print "$domain/$label" >/dev/null 2>&1; }

marked_off() {
	launchctl print-disabled "$domain" 2>/dev/null |
		grep -Eq "\"$label\" => (disabled|true)"
}

# A throwaway session with two panes side by side, the left one focused.
out=$(rex new GR-TEST --json -- sleep 600)
session=$(jq -r .session_id <<<"$out")
sessions+=("$session")
left=$(jq -r '.initial_windows[0].block_ids[0]' <<<"$out")
right=$(rex api call session.new_split \
	"{\"session_id\":\"$session\",\"anchor_id\":\"$left\",\"direction\":\"horizontal\",\"side\":\"after\",\"ratio\":0.5,\"layout\":{\"block\":{\"flavor\":\"com.superlogical.terminal.shell\"}}}" |
	jq -r '.block_ids[0]')

focus() {
	rex api call session.focus_block "{\"session_id\":\"$session\",\"block_id\":\"$1\"}" >/dev/null
	sleep 0.9 # the resize debounces for 0.12 s
}

ratio() {
	rex api call -s "$session" session.view |
		jq -r '.windows[0].layers[] | select(.kind == "tiled") | .layout.split.ratio // "none"'
}

# ── On: the split follows the focus ───────────────────────────────────────

"$COMMAND" on >/dev/null
assert_equal "on" "$(launchctl print "$domain/$label" >/dev/null 2>&1 && echo on || echo off)" "the command loads the job"
assert_equal "on" "$("$COMMAND" status | head -1 | sed 's/golden-ratio: //')" "status reports on"

focus "$left"
left_ratio=$(ratio)
focus "$right"
right_ratio=$(ratio)
if [[ "$left_ratio" == "$right_ratio" ]]; then
	printf 'not ok - the split follows the focus while the job runs\n  both: %s\n' "$left_ratio" >&2
	failures=$((failures + 1))
else
	printf 'ok - the split follows the focus while the job runs\n'
fi

# ── Off: the split stays where it is ──────────────────────────────────────

"$COMMAND" off >/dev/null
assert_equal "off" "$(loaded && echo on || echo off)" "the command unloads the job"
assert_equal "off" "$("$COMMAND" status | head -1 | sed 's/golden-ratio: //')" "status reports off"

if marked_off; then
	printf 'ok - the job is marked so it stays off after a login\n'
else
	printf 'not ok - the job is marked so it stays off after a login\n' >&2
	failures=$((failures + 1))
fi

focus "$left"
off_left=$(ratio)
focus "$right"
off_right=$(ratio)
assert_equal "$off_left" "$off_right" "the split stays put while the job is off"

# A login would load the agent again; the loader must respect the mark.
"$ROOT_DIR/launchd/install.sh" >/dev/null 2>&1 || true
assert_equal "off" "$(loaded && echo on || echo off)" "the loader leaves a job that was turned off alone"

# ── The palette offers the same three words ───────────────────────────────

listed=$(rex actions 2>/dev/null || true)
assert_contains "Golden Ratio: On" "$listed" "the palette lists Golden Ratio: On"
assert_contains "Golden Ratio: Off" "$listed" "the palette lists Golden Ratio: Off"
assert_contains "Golden Ratio: Status" "$listed" "the palette lists Golden Ratio: Status"
assert_equal "$("$COMMAND" status | head -1)" "$(rex do golden_ratio_status 2>&1 | jq -r .state)" "the palette's status action reads the same state"

# ── On again: the split follows the focus once more ───────────────────────

"$COMMAND" on >/dev/null
if marked_off; then
	printf 'not ok - turning the job on clears the mark\n' >&2
	failures=$((failures + 1))
else
	printf 'ok - turning the job on clears the mark\n'
fi

focus "$right"
on_right=$(ratio)
focus "$left"
on_left=$(ratio)
if [[ "$on_right" == "$on_left" ]]; then
	printf 'not ok - the split follows the focus again after the job returns\n  both: %s\n' "$on_right" >&2
	failures=$((failures + 1))
else
	printf 'ok - the split follows the focus again after the job returns\n'
fi

if ((failures > 0)); then
	printf '%d failure(s)\n' "$failures" >&2
	exit 1
fi
printf 'all golden-ratio toggle tests passed\n'
