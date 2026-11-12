#!/usr/bin/env bash
#
# tests/tab-key.test.sh — cmd+[ and cmd+ step back and forward through tabs
#
# The server resolves the keys and only the app shows a tab, so the test checks both:
# `rex keymap` names the two keys, then a real press through System Events moves the
# app's active tab by exactly one. The press needs Accessibility permission for the
# terminal that runs the test, and the app must be frontmost to receive it.
#
# The test puts the app back on the session and tab it found, and it needs a session
# with at least two tabs.

set -euo pipefail

if ! command -v rex >/dev/null 2>&1; then
	printf 'not ok - the rex CLI is not on PATH, so the key cannot be driven\n' >&2
	exit 1
fi

account="com.superlogical.rex"
plist="$HOME/Library/Preferences/$account.plist"

app=$(rex client list --json 2>/dev/null | jq -r '.clients[] | select(.info.kind == "app") | .client_id' | head -1)
if [[ -z "$app" ]]; then
	printf 'not ok - the Rex app is not connected\n' >&2
	exit 1
fi

shown_session() {
	python3 - "$plist" <<'PY'
import re, sys
raw = open(sys.argv[1], "rb").read()
match = re.search(rb'\{"sessionID":"(session:[^"]+)"\}', raw)
print(match.group(1).decode() if match else "")
PY
}

session=$(shown_session)
if [[ -z "$session" ]]; then
	printf 'not ok - the app records no shown session in %s\n' "$plist" >&2
	exit 1
fi

windows() { rex window list -s "$session" --json 2>/dev/null; }
active_tab() { windows | jq -r '.active_window_id'; }
tab_ids() { windows | jq -r '.windows[].window_id'; }

tab_count=$(tab_ids | grep -c . || true)
if [[ "$tab_count" -lt 2 ]]; then
	printf 'not ok - the shown session has %s tab(s), and the key needs two\n' "$tab_count" >&2
	exit 1
fi

original_tab=$(active_tab)

cleanup() {
	show_tab "$(tab_index_of "$original_tab")"
	select_session
}
trap cleanup EXIT

tab_index_of() {
	local wanted="$1" index=0 tab
	while read -r tab; do
		index=$((index + 1))
		if [[ "$tab" == "$wanted" ]]; then
			printf '%s' "$index"
			return 0
		fi
	done < <(tab_ids)
	printf '1'
}

show_tab() {
	rex api call client.perform \
		"{\"client_id\":\"$app\",\"action\":\"client.tab.goto\",\"args\":{\"index\":$1},\"session_id\":\"$session\",\"origin\":\"key\"}" \
		>/dev/null 2>&1 || true
}

select_session() {
	rex api call client.perform \
		"{\"client_id\":\"$app\",\"action\":\"session.select\",\"args\":{\"session_id\":\"$session\"},\"session_id\":\"$session\",\"origin\":\"key\"}" \
		>/dev/null 2>&1 || true
}

# The app picks a tab on its own when a session is shown, so the test names the tab
# it measures from before it presses anything, and fails if the app shows another.
select_session
show_tab "$(tab_index_of "$original_tab")"
sleep 0.5
if [[ "$(active_tab)" != "$original_tab" ]]; then
	printf 'not ok - the app would not show the tab the test measures from\n  wanted:  %s\n  showing: %s\n' "$original_tab" "$(active_tab)" >&2
	exit 1
fi

press() {
	local key="$1" err
	if ! err=$(osascript -e "tell application id \"$account\" to activate" \
		-e "tell application \"System Events\" to keystroke \"$key\" using command down" 2>&1); then
		printf 'not ok - System Events refused the press: %s\n' "$err" >&2
		exit 1
	fi
	sleep 0.8
}

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

# The neighbour of a tab in the list, wrapping at both ends as the app does.
neighbour() {
	local wanted="$1" step="$2" index=0 position=0 tab
	local tabs=()
	while read -r tab; do tabs+=("$tab"); done < <(tab_ids)
	for index in "${!tabs[@]}"; do
		if [[ "${tabs[$index]}" == "$wanted" ]]; then position="$index"; fi
	done
	local count="${#tabs[@]}"
	local target=$(((position + step + count) % count))
	printf '%s' "${tabs[$target]}"
}

# ── The server binds both keys ─────────────────────────────────────────────

keymap=$(rex keymap --json 2>/dev/null)
for pair in "cmd+[BracketLeft]:client.tab.previous" "cmd+[BracketRight]:client.tab.next"; do
	key="${pair%%:*}"
	action="${pair##*:}"
	resolved=$(printf '%s\n' "$keymap" | jq -r --arg key "$key" '.bindings[] | select(.keys[0] == $key) | .action' | head -1)
	assert_equal "$action" "$resolved" "the config binds $key to $action" || true
done
if ((failures > 0)); then
	printf 'the keymap does not carry both keys, so no press is sent\n' >&2
	exit 1
fi

# ── A press moves the shown tab by one ─────────────────────────────────────

forward=$(neighbour "$original_tab" 1)
press "]"
assert_equal "$forward" "$(active_tab)" "cmd+] shows the next tab" || true

press "["
assert_equal "$original_tab" "$(active_tab)" "cmd+[ shows the tab before it" || true

back=$(neighbour "$original_tab" -1)
press "["
assert_equal "$back" "$(active_tab)" "cmd+[ shows the previous tab from the first one" || true

press "]"
assert_equal "$original_tab" "$(active_tab)" "cmd+] returns to the tab the test found" || true

if [[ "$(active_tab)" != "$original_tab" ]]; then
	printf 'not ok - the app is left on %s, not %s\n' "$(active_tab)" "$original_tab" >&2
	failures=$((failures + 1))
fi

if ((failures > 0)); then
	printf '%d failure(s)\n' "$failures" >&2
	exit 1
fi
printf 'all tab key tests passed\n'
