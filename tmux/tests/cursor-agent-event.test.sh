#!/usr/bin/env bash
#
# Integration test: Cursor hook events → shared tmux monitor states.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/cursor-agent-event.sh"
TMP_DIR="$(mktemp -d)"
STORE="$TMP_DIR/options"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash

set -euo pipefail

store="${TMUX_OPTION_STORE:?}"

get_option() {
	local option="$1"
	awk -F '\t' -v key="$option" '$1 == key { value = $2 } END { if (value != "") print value }' "$store" 2>/dev/null || true
}

set_option() {
	local option="$1"
	local value="$2"
	local tmp="${store}.$$"

	touch "$store"
	awk -F '\t' -v key="$option" '$1 != key { print }' "$store" >"$tmp"
	printf '%s\t%s\n' "$option" "$value" >>"$tmp"
	mv "$tmp" "$store"
}

unset_option() {
	local option="$1"
	local tmp="${store}.$$"

	touch "$store"
	awk -F '\t' -v key="$option" '$1 != key { print }' "$store" >"$tmp"
	mv "$tmp" "$store"
}

case "$1" in
show-options)
	get_option "$3"
	;;
set-option)
	if [[ "${2:-}" == "-guq" ]]; then
		unset_option "$3"
	else
		set_option "$3" "${4:-}"
	fi
	;;
list-panes)
	printf '%%9\n%%10\n'
	;;
display-message)
	if [[ "${5:-}" == '#{pane_tty}' ]]; then
		case "${4:-}" in
		%9) printf '/dev/ttys009\n' ;;
		%10) printf '/dev/ttys010\n' ;;
		*) exit 1 ;;
		esac
	elif [[ "${5:-}" == '#{pane_current_path}' ]]; then
		case "${4:-}" in
		%9) printf '/tmp/project-a\n' ;;
		%10) printf '/tmp/project-b\n' ;;
		*) exit 1 ;;
		esac
	else
		printf '%s\n' "${TMUX_WINDOW_NAME:-cursor-window}"
	fi
	;;
refresh-client)
	exit 0
	;;
*)
	exit 1
	;;
esac
FAKE_TMUX
chmod +x "$TMP_DIR/tmux"

cat >"$TMP_DIR/ps" <<'FAKE_PS'
#!/usr/bin/env bash

set -euo pipefail

tty=""
pid=""
while [[ $# -gt 0 ]]; do
	case "$1" in
	-p)
		pid="$2"
		shift 2
		;;
	-t)
		tty="$2"
		shift 2
		;;
	-o)
		shift 2
		;;
	*)
		shift
		;;
	esac
done

if [[ -n "$pid" ]]; then
	case "$pid" in
	501) printf 'ttys009\n' ;;
	502) printf 'ttys010\n' ;;
	*) exit 1 ;;
	esac
	exit 0
fi

case "$tty" in
ttys009)
	printf 'agent /Users/walkerw/.local/bin/agent --use-system-ca /Users/walkerw/.local/share/cursor-agent/versions/2026.06.15/index.js\n'
	;;
ttys010)
	printf 'agent /Users/walkerw/.local/bin/agent --use-system-ca /Users/walkerw/.local/share/cursor-agent/versions/2026.06.15/index.js\n'
	;;
*)
	exit 1
	;;
esac
FAKE_PS
chmod +x "$TMP_DIR/ps"

cat >"$TMP_DIR/pgrep" <<'FAKE_PGREP'
#!/usr/bin/env bash

if [[ "${1:-}" == "-f" ]]; then
	case "${2:-}" in
	*cursor-agent/versions/*)
		printf '501\n502\n'
		;;
	*.local/bin/agent*)
		printf '501\n502\n'
		;;
	*)
		exit 1
		;;
	esac
fi
FAKE_PGREP
chmod +x "$TMP_DIR/pgrep"

cat >"$TMP_DIR/agent-status.sh" <<'FAKE_STATUS'
#!/usr/bin/env bash
exit 0
FAKE_STATUS
chmod +x "$TMP_DIR/agent-status.sh"

assert_equal() {
	local expected="$1"
	local actual="$2"
	local name="$3"

	if [[ "$actual" != "$expected" ]]; then
		printf 'not ok - %s\n' "$name" >&2
		printf 'expected: %s\n' "$expected" >&2
		printf 'actual:   %s\n' "$actual" >&2
		exit 1
	fi

	printf 'ok - %s\n' "$name"
}

PATH="$TMP_DIR:$PATH"
export TMUX_OPTION_STORE="$STORE"
export TMUX_WINDOW_NAME="cursor-window"
export AGENT_MONITOR_NOW="100"
export AGENT_MONITOR_SYNC="1"
export AGENT_MONITOR_STATE_FILE="$TMP_DIR/agent-state.tsv"
export AGENT_MONITOR_SKETCHYBAR_CACHE="$TMP_DIR/sketchybar-items.cache"
export AGENT_MONITOR_SKIP_SKETCHYBAR=1
unset TMUX_PANE

session_a='{"session_id":"aaaa-bbbb-cccc-dddd","conversation_id":"aaaa-bbbb-cccc-dddd","workspace_roots":["/tmp/project-a"]}'
session_b='{"session_id":"eeee-ffff-0000-1111","conversation_id":"eeee-ffff-0000-1111","workspace_roots":["/tmp/project-b"]}'
session_a_prompt='{"session_id":"zzzz-yyyy-xxxx-wwww","conversation_id":"aaaa-bbbb-cccc-dddd","workspace_roots":["/tmp/project-a"]}'

printf '%s' "$session_a" | TMUX_PANE="%9" "$SCRIPT" sessionStart
assert_equal "9" "$(tmux show-options -gqv @agent_monitor_instances)" "sessionStart registers pane instance"
assert_equal "cursor" "$(tmux show-options -gqv @agent_monitor_9_name)" "sessionStart stores cursor agent name"
assert_equal "idle" "$(tmux show-options -gqv @agent_monitor_9_state)" "sessionStart maps to idle"
assert_equal "%9" "$(tmux show-options -gqv @cursor_agent_session_aaaa_bbbb_cccc_dddd_pane)" "sessionStart stores session pane mapping"

printf '%s' "$session_a" | "$SCRIPT" beforeSubmitPrompt
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_9_state)" "prompt submit is running"

printf '%s' "$session_a" | "$SCRIPT" stop
assert_equal "needs-attention" "$(tmux show-options -gqv @agent_monitor_9_state)" "stop needs attention"

unset TMUX_PANE
printf '%s' "$session_a_prompt" | AGENT_MONITOR_NOW=103 "$SCRIPT" beforeSubmitPrompt
assert_equal "needs-attention" "$(tmux show-options -gqv @agent_monitor_9_state)" "post-stop prompt within grace window stays terminal"

printf '%s' "$session_a" | "$SCRIPT" preToolUse
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_9_state)" "tool start resumes running after stop"

printf '%s' "$session_a_prompt" | AGENT_MONITOR_NOW=200 "$SCRIPT" beforeSubmitPrompt
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_9_state)" "conversation_id alias routes prompt to mapped pane"

printf '%s' "$session_b" | TMUX_PANE="%10" "$SCRIPT" sessionStart
assert_equal "9 10" "$(tmux show-options -gqv @agent_monitor_instances)" "second session registers another pane"
assert_equal "idle" "$(tmux show-options -gqv @agent_monitor_10_state)" "second session starts idle"
assert_equal "%10" "$(tmux show-options -gqv @cursor_agent_session_eeee_ffff_0000_1111_pane)" "second session stores its own pane"

unset TMUX_PANE
printf '%s' "$session_a_prompt" | AGENT_MONITOR_NOW=200 "$SCRIPT" beforeSubmitPrompt
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_9_state)" "session mapping keeps first session on pane 9"
assert_equal "idle" "$(tmux show-options -gqv @agent_monitor_10_state)" "second session is unaffected by first session prompt"

printf '%s' "$session_b" | "$SCRIPT" beforeSubmitPrompt
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_10_state)" "second session prompt uses mapped pane 10"

printf '%s' "$session_a" | "$SCRIPT" sessionEnd
assert_equal "10" "$(tmux show-options -gqv @agent_monitor_instances)" "sessionEnd removes first session record"
assert_equal "" "$(tmux show-options -gqv @agent_monitor_9_name)" "sessionEnd unsets first session metadata"
assert_equal "" "$(tmux show-options -gqv @cursor_agent_session_aaaa_bbbb_cccc_dddd_pane)" "sessionEnd clears session mapping"
assert_equal "cursor" "$(tmux show-options -gqv @agent_monitor_10_name)" "sessionEnd keeps second session record"

printf 'All cursor-agent-event tests passed.\n'
