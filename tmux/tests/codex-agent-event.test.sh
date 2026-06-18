#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/codex-agent-event.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash

set -euo pipefail

case "$1" in
show-options)
	return 0 2>/dev/null || exit 0
	;;
display-message)
	printf 'Window\n'
	;;
set-option)
	[[ "$3" == "@agent_monitor_status" ]] && exit 0
	printf '%s\n' "$*" >>"$TMUX_LOG"
	;;
*)
	exit 1
	;;
esac
FAKE_TMUX
chmod +x "$TMP_DIR/tmux"

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
export TMUX_PANE="%1"
export TMUX_LOG="$TMP_DIR/tmux.log"
export AGENT_MONITOR_NOW=1000
export AGENT_MONITOR_STATE_FILE="$TMP_DIR/agent-state.tsv"
export AGENT_MONITOR_SKETCHYBAR_CACHE="$TMP_DIR/sketchybar-items.cache"
export AGENT_MONITOR_SKIP_SKETCHYBAR=1

"$SCRIPT" UserPromptSubmit
expected='set-option -gq @agent_monitor_instances 1
set-option -gq @agent_monitor_1_name codex
set-option -gq @agent_monitor_1_state running
set-option -gq @agent_monitor_1_label Window
set-option -gq @agent_monitor_1_pane %1
set-option -gq @agent_monitor_1_session_id 
set-option -gq @agent_monitor_1_updated_at 1000'
actual="$(cat "$TMUX_LOG")"
assert_equal "$expected" "$actual" "maps prompt submit to running"

: >"$TMUX_LOG"
"$SCRIPT" Notification
expected='set-option -gq @agent_monitor_instances 1
set-option -gq @agent_monitor_1_name codex
set-option -gq @agent_monitor_1_state idle
set-option -gq @agent_monitor_1_label Window
set-option -gq @agent_monitor_1_pane %1
set-option -gq @agent_monitor_1_session_id 
set-option -gq @agent_monitor_1_updated_at 1000'
actual="$(cat "$TMUX_LOG")"
assert_equal "$expected" "$actual" "maps notification to idle"

: >"$TMUX_LOG"
"$SCRIPT" Stop
expected='set-option -gq @agent_monitor_instances 1
set-option -gq @agent_monitor_1_name codex
set-option -gq @agent_monitor_1_state needs-attention
set-option -gq @agent_monitor_1_label Window
set-option -gq @agent_monitor_1_pane %1
set-option -gq @agent_monitor_1_session_id 
set-option -gq @agent_monitor_1_updated_at 1000'
actual="$(cat "$TMUX_LOG")"
assert_equal "$expected" "$actual" "maps stop to needs attention"

: >"$TMUX_LOG"
printf '{"hook_event_name":"PermissionRequest"}' | "$SCRIPT"
expected='set-option -gq @agent_monitor_instances 1
set-option -gq @agent_monitor_1_name codex
set-option -gq @agent_monitor_1_state needs-help
set-option -gq @agent_monitor_1_label Window
set-option -gq @agent_monitor_1_pane %1
set-option -gq @agent_monitor_1_session_id 
set-option -gq @agent_monitor_1_updated_at 1000'
actual="$(cat "$TMUX_LOG")"
assert_equal "$expected" "$actual" "reads event name from stdin json"
