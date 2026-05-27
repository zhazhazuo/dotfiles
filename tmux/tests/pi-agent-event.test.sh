#!/usr/bin/env bash
#
# Integration test: Pi agent events → shared tmux monitor states.

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
printf 'pi pi\n'
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
export TMUX_WINDOW_NAME="pi-session"
export AGENT_MONITOR_NOW="200"

# ── Generic event mapping (used by Pi extension) ──

# session_start → SessionStart → idle
printf '%s\n' '{"session_id":"pi-sess-1","cwd":"/tmp/project"}' | "$SCRIPT" pi SessionStart
assert_equal "9" "$(tmux show-options -gqv @agent_monitor_instances)" "pi: registers pane as instance id"
assert_equal "pi" "$(tmux show-options -gqv @agent_monitor_9_name)" "pi: stores agent name"
assert_equal "idle" "$(tmux show-options -gqv @agent_monitor_9_state)" "pi: SessionStart → idle"
assert_equal "pi-session" "$(tmux show-options -gqv @agent_monitor_9_label)" "pi: uses window name as label"
assert_equal "pi-sess-1" "$(tmux show-options -gqv @agent_monitor_9_session_id)" "pi: stores session id"

# agent_start → RunStart → running
printf '%s\n' '{"session_id":"pi-sess-1"}' | "$SCRIPT" pi RunStart
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_9_state)" "pi: RunStart → running"

# agent_end → TurnComplete → needs-attention
printf '%s\n' '{"session_id":"pi-sess-1"}' | "$SCRIPT" pi TurnComplete
assert_equal "needs-attention" "$(tmux show-options -gqv @agent_monitor_9_state)" "pi: TurnComplete → needs-attention"

# window rename → label updates, no duplicate instance
export TMUX_WINDOW_NAME="pi-renamed"
printf '%s\n' '{"session_id":"pi-sess-1"}' | "$SCRIPT" pi RunStart
assert_equal "9" "$(tmux show-options -gqv @agent_monitor_instances)" "pi: window rename does not duplicate"
assert_equal "pi-renamed" "$(tmux show-options -gqv @agent_monitor_9_label)" "pi: window rename updates label"

# ── Unknown event → idle ──
printf '%s\n' '{"session_id":"pi-sess-1"}' | "$SCRIPT" pi UnknownEvent
assert_equal "idle" "$(tmux show-options -gqv @agent_monitor_9_state)" "pi: unknown event → idle"

# ── Pi-specific events (fallback section in state_for_event) ──

# AgentStart → running (Pi-specific name)
printf '%s\n' '{"session_id":"pi-sess-1"}' | "$SCRIPT" pi AgentStart
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_9_state)" "pi: AgentStart (specific) → running"

# AgentEnd → needs-attention (Pi-specific name)
printf '%s\n' '{"session_id":"pi-sess-1"}' | "$SCRIPT" pi AgentEnd
assert_equal "needs-attention" "$(tmux show-options -gqv @agent_monitor_9_state)" "pi: AgentEnd (specific) → needs-attention"

# SessionShutdown → idle (Pi-specific name)
printf '%s\n' '{"session_id":"pi-sess-1"}' | "$SCRIPT" pi SessionShutdown
assert_equal "idle" "$(tmux show-options -gqv @agent_monitor_9_state)" "pi: SessionShutdown (specific) → idle"

# ── Codex still works (regression check) ──
printf '%s\n' '{"session_id":"codex-sess-1"}' | "$SCRIPT" codex UserPromptSubmit
assert_equal "running" "$(tmux show-options -gqv @agent_monitor_9_state)" "codex: UserPromptSubmit → running (regression)"

printf '%s\n' '{"session_id":"codex-sess-1"}' | "$SCRIPT" codex Stop
assert_equal "needs-attention" "$(tmux show-options -gqv @agent_monitor_9_state)" "codex: Stop → needs-attention (regression)"

# ── Deduplication still works ──
printf '@agent_monitor_instances\t9 9 pi-dupe 9\n' >"$STORE"
printf '%s\n' '{"session_id":"pi-sess-1"}' | "$SCRIPT" pi SessionStart
assert_equal "9 pi-dupe" "$(tmux show-options -gqv @agent_monitor_instances)" "pi: deduplicates instance list"

echo ""
echo "All pi-agent-event tests passed."
