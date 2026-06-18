#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/agent-monitor-check.sh"
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

case "$1" in
show-options)
	get_option "$3"
	;;
set-option)
	set_option "$3" "$4"
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
	else
		printf '%s\n' "${TMUX_WINDOW_NAME:-Window}"
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
printf 'zsh zsh\n'
printf 'codex codex\n'
FAKE_PS
chmod +x "$TMP_DIR/ps"

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
export TMUX_PANE="%9"
export TMUX_WINDOW_NAME="agent-window"
export AGENT_MONITOR_NOW="100"
export AGENT_MONITOR_STATE_FILE="$TMP_DIR/agent-state.tsv"
export AGENT_MONITOR_SKETCHYBAR_CACHE="$TMP_DIR/sketchybar-items.cache"
export AGENT_MONITOR_SKIP_SKETCHYBAR=1

printf '%s\n' '{"session_id":"session-1","cwd":"/tmp/project"}' | "$SCRIPT" codex SessionStart
assert_equal "9" "$(tmux show-options -gqv @agent_monitor_instances)" "registers pane as canonical instance id"
assert_equal "codex" "$(tmux show-options -gqv @agent_monitor_9_name)" "stores agent name"
assert_equal "idle" "$(tmux show-options -gqv @agent_monitor_9_state)" "session start is idle"
assert_equal "agent-window" "$(tmux show-options -gqv @agent_monitor_9_label)" "uses window name as label"
assert_equal "session-1" "$(tmux show-options -gqv @agent_monitor_9_session_id)" "stores session id as metadata"

printf '%s\n' '{"session_id":"session-1"}' | "$SCRIPT" codex UserPromptSubmit
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_9_state)" "prompt submit is running"

printf '%s\n' '{"session_id":"session-1"}' | "$SCRIPT" codex PermissionRequest
assert_equal "needs-help" "$(tmux show-options -gqv @agent_monitor_9_state)" "permission request needs help"

printf '%s\n' '{"session_id":"session-1"}' | "$SCRIPT" codex Stop
assert_equal "needs-attention" "$(tmux show-options -gqv @agent_monitor_9_state)" "stop needs attention"

export TMUX_WINDOW_NAME="renamed-window"
printf '%s\n' '{"session_id":"session-1"}' | "$SCRIPT" codex UserPromptSubmit
assert_equal "9" "$(tmux show-options -gqv @agent_monitor_instances)" "window rename does not create instance"
assert_equal "renamed-window" "$(tmux show-options -gqv @agent_monitor_9_label)" "window rename updates label"

printf '@agent_monitor_instances\t9 9 other 9\n' >"$STORE"
printf '%s\n' '{"session_id":"session-1"}' | "$SCRIPT" codex PreToolUse
assert_equal "9 other" "$(tmux show-options -gqv @agent_monitor_instances)" "deduplicates existing instance list"
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_9_state)" "tool hooks reconcile running state"

updated_before="$(tmux show-options -gqv @agent_monitor_9_updated_at)"
printf '%s\n' '{"session_id":"session-1"}' | "$SCRIPT" codex PreToolUse
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_9_state)" "repeat tool use stays running"
assert_equal "$updated_before" "$(tmux show-options -gqv @agent_monitor_9_updated_at)" "repeat tool use is a no-op fast path"

printf '%s\n' '{"session_id":"session-1","tool_name":"functions.request_user_input"}' | "$SCRIPT" codex PreToolUse
assert_equal "needs-help" "$(tmux show-options -gqv @agent_monitor_9_state)" "ask-question tool needs help"

printf '%s\n' '{"session_id":"session-1","tool_name":"functions.request_user_input"}' | "$SCRIPT" codex PostToolUse
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_9_state)" "ask-question tool completion returns running"

printf '%s\n' '{"session_id":"session-1","tool_name":"Bash","tool_input":{"sandbox_permissions":"require_escalated"}}' | "$SCRIPT" codex PreToolUse
assert_equal "needs-help" "$(tmux show-options -gqv @agent_monitor_9_state)" "escalated tool request needs help"

export TMUX_PANE="%10"
printf '%s\n' '{"session_id":"session-2"}' | "$SCRIPT" codex SessionStart
assert_equal "9 other 10" "$(tmux show-options -gqv @agent_monitor_instances)" "appends second pane instance once"

export AGENT_MONITOR_INSTANCE_ID="logical-agent-A"
printf '%s\n' '{"session_id":"session-3"}' | "$SCRIPT" codex UserPromptSubmit
assert_equal "9 other 10 logical_agent_A" "$(tmux show-options -gqv @agent_monitor_instances)" "explicit instance id overrides pane id"
assert_equal "%10" "$(tmux show-options -gqv @agent_monitor_logical_agent_A_pane)" "explicit instance stores pane metadata"
