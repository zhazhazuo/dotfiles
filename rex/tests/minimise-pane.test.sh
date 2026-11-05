#!/usr/bin/env bash
#
# tests/minimise-pane.test.sh — the minimise_pane and restore_pane actions
#
# The two actions change a window's layout, so a fake proves nothing: the test
# drives the Rex server and asserts on session.view. Each case gets its own
# throwaway session, and the caller's focused pane is taken back at the end,
# because restoring a pane focuses it and that moves the app's view.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v rex >/dev/null 2>&1; then
	printf 'not ok - the rex CLI is not on PATH, so the actions cannot be driven\n' >&2
	exit 1
fi

listed=no
for _ in 1 2 3 4 5; do
	if rex actions 2>/dev/null | grep -q '^minimise_pane '; then
		listed=yes
		break
	fi
	sleep 0.5
done
if [[ "$listed" == no ]]; then
	printf 'not ok - the running Rex config defines no minimise_pane action\n' >&2
	printf '  run: rex api call server.config_reload\n' >&2
	exit 1
fi

sessions=()

cleanup() {
	local s
	for s in "${sessions[@]:-}"; do
		[[ -n "$s" ]] && rex kill "$s" >/dev/null 2>&1
	done
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

# Prints "session_id block_id" for a new throwaway session with one tiled pane.
new_pane_session() {
	local out sid
	out=$(rex new "$1" --json -- sleep 600)
	sid=$(jq -r .session_id <<<"$out")
	sessions+=("$sid")
	printf '%s %s\n' "$sid" "$(jq -r '.initial_windows[0].block_ids[0]' <<<"$out")"
}

# Splits beside a block and prints the new block's id.
split_beside() {
	local sid="$1" anchor="$2" ratio="$3"
	rex api call session.new_split \
		"{\"session_id\":\"$sid\",\"anchor_id\":\"$anchor\",\"direction\":\"horizontal\",\"side\":\"after\",\"ratio\":$ratio,\"layout\":{\"block\":{\"flavor\":\"com.superlogical.terminal.shell\"}}}" |
		jq -r '.block_ids[0]'
}

# Prints a new floating layer's block id.
new_floating_pane() {
	local sid="$1"
	rex api call session.new_layer \
		"{\"session_id\":\"$sid\",\"bounds\":[0.2,0.2,0.5,0.5],\"layout\":{\"block\":{\"flavor\":\"com.superlogical.terminal.shell\"}}}" |
		jq -r '.block_ids[0]'
}

view() { rex api call -s "$1" session.view; }

tiled_leaves() {
	view "$1" | jq -r '[.windows[0].layers[] | select(.kind == "tiled") | .layout | .. | objects | select(has("block_id")) | .block_id] | join(" ")'
}

floating_states() {
	view "$1" | jq -r '[.windows[0].layers[] | select(.kind == "floating") | (.state // "normal")] | join(" ")'
}

tiled_split() {
	view "$1" | jq -r ".windows[0].layers[] | select(.kind == \"tiled\") | .layout.split.$2 // \"none\""
}

focused_block() {
	view "$1" | jq -r '.windows[0].focused_block_id // "none"'
}

# A window must keep a visible pane, so the last tiled pane cannot be hidden.
read -r lone_session lone_block <<<"$(new_pane_session MIN-TEST-LONE)"
refusal=$(rex do -s "$lone_session" minimise_pane block="$lone_block" 2>&1 || true)
assert_contains "must keep a visible pane" "$refusal" "refusing to hide the last tiled pane"
assert_equal "$lone_block" "$(tiled_leaves "$lone_session")" "the refused pane stays in the layout"
assert_equal "" "$(floating_states "$lone_session")" "the refusal leaves no floating layer"

# A pane beside another one goes away and waits as a minimised layer.
read -r pair_session pair_left <<<"$(new_pane_session MIN-TEST-PAIR)"
pair_right=$(split_beside "$pair_session" "$pair_left" 0.3)
rex do -s "$pair_session" minimise_pane block="$pair_right" >/dev/null
assert_equal "$pair_left" "$(tiled_leaves "$pair_session")" "the minimised pane leaves the layout"
assert_equal "minimized" "$(floating_states "$pair_session")" "the pane waits as a minimised layer"

# The reverse puts it back in the split it came from, with the same geometry.
rex do -s "$pair_session" restore_pane >/dev/null
assert_equal "$pair_left $pair_right" "$(tiled_leaves "$pair_session")" "the pane returns beside its old neighbour"
assert_equal "" "$(floating_states "$pair_session")" "the minimised layer is gone"
assert_equal "horizontal" "$(tiled_split "$pair_session" direction)" "the old split direction returns"
assert_equal "0.3" "$(tiled_split "$pair_session" ratio)" "the old split ratio returns"
assert_equal "$pair_right" "$(focused_block "$pair_session")" "the restored pane takes focus"

# The record is used once, so a second restore has nothing to do.
spare=$(rex do -s "$pair_session" restore_pane 2>&1 || true)
assert_contains "no pane was minimised" "$spare" "a second restore reports nothing left to restore"

# The middle of three panes sits in a nested split, so its place comes back as
# a split beside its neighbour rather than as a copy of the old tree.
read -r row_session row_left <<<"$(new_pane_session MIN-TEST-ROW)"
row_middle=$(split_beside "$row_session" "$row_left" 0.5)
row_right=$(split_beside "$row_session" "$row_middle" 0.5)
assert_equal "$row_left $row_middle $row_right" "$(tiled_leaves "$row_session")" "three panes start in a row"
rex do -s "$row_session" minimise_pane block="$row_middle" >/dev/null
assert_equal "$row_left $row_right" "$(tiled_leaves "$row_session")" "the middle pane leaves the row"
rex do -s "$row_session" restore_pane >/dev/null
assert_equal "$row_left $row_middle $row_right" "$(tiled_leaves "$row_session")" "the middle pane returns between its neighbours"

# A pane that was already floating comes back on screen, not into the layout.
read -r float_session float_tiled <<<"$(new_pane_session MIN-TEST-FLOAT)"
float_block=$(new_floating_pane "$float_session")
rex do -s "$float_session" minimise_pane block="$float_block" >/dev/null
assert_equal "minimized" "$(floating_states "$float_session")" "a floating pane is minimised in place"
rex do -s "$float_session" restore_pane >/dev/null
assert_equal "normal" "$(floating_states "$float_session")" "the floating pane is back on screen"
assert_equal "$float_block" "$(focused_block "$float_session")" "the restored floating pane takes focus"

if ((failures > 0)); then
	printf '%d test(s) failed\n' "$failures" >&2
	exit 1
fi
printf 'all tests passed\n'
