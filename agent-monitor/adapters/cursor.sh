#!/usr/bin/env bash
#
# agent-monitor/adapters/cursor.sh — Cursor agent adapter
#
# Called by ~/.cursor/hooks/agent-monitor.sh with:
#   $1      = Cursor hook event name (e.g. "sessionStart", "stop")
#   stdin   = the raw Cursor hook JSON payload
#
# Maps Cursor events to generic events, resolves tmux pane identity,
# then calls agent-monitor reconcile.

set +e +u # fail open — never break the host application

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${ADAPTER_DIR}/../bin/agent-monitor"

event="${1:-}"
input="$(cat 2>/dev/null || true)"

agent_name="cursor"
post_stop_grace_secs=5

# ── Helpers ──────────────────────────────────────────────────────────────

sanitize_id() {
	printf '%s' "$1" | tr -c '[:alnum:]_' '_' | sed 's/^_*//; s/_*$//'
}

json_field() {
	local field="$1"
	printf '%s' "$input" | jq -r --arg field "$field" '.[$field] // empty' 2>/dev/null
}

# ── Session → Pane Mapping ───────────────────────────────────────────────
# Cursor doesn't always set TMUX_PANE. We maintain a mapping in tmux options.

session_option_key() {
	printf '@cursor_agent_session_%s_%s' "$(sanitize_id "$2")" "$1"
}

store_session_pane() {
	local sid="$1" pane="$2"
	[[ -z "$sid" || -z "$pane" ]] && return 0
	tmux set-option -gq "$(session_option_key pane "$sid")" "$pane" 2>/dev/null || true
}

clear_session_mapping() {
	local sid="$1"
	[[ -z "$sid" ]] && return 0
	tmux set-option -guq "$(session_option_key pane "$sid")" 2>/dev/null || true
}

lookup_session_pane() {
	local sid="$1"
	[[ -z "$sid" ]] && return 1
	tmux show-options -gqv "$(session_option_key pane "$sid")" 2>/dev/null || true
}

# Detect tmux pane from cursor-agent process PID
detect_tmux_pane_from_pid() {
	local agent_pid="$1" agent_tty pane_lines pane_id
	[[ -z "$agent_pid" ]] && return 1
	agent_tty="$(ps -p "$agent_pid" -o tty= 2>/dev/null | tr -d ' ')"
	[[ -z "$agent_tty" || "$agent_tty" == "??" ]] && return 1
	pane_id="$(tmux list-panes -a -F '#{pane_id} #{pane_tty}' 2>/dev/null | grep "/dev/${agent_tty}$" | awk '{print $1}')"
	[[ -n "$pane_id" ]] && printf '%s' "$pane_id" && return 0
	return 1
}

find_cursor_agent_pid() {
	local pid
	pid="$(pgrep -f 'cursor-agent/versions/' 2>/dev/null | tail -1)"
	[[ -n "$pid" ]] && printf '%s' "$pid" && return 0
	pid="$(pgrep -f '\.local/bin/agent' 2>/dev/null | tail -1)"
	[[ -n "$pid" ]] && printf '%s' "$pid" && return 0
	return 1
}

# ── Parse Cursor JSON ────────────────────────────────────────────────────

session_id="$(json_field session_id)"
conversation_id="$(json_field conversation_id)"
cwd="$(printf '%s' "$input" | jq -r '.workspace_roots[0] // empty' 2>/dev/null)"

# ── Map Cursor Events → Generic ──────────────────────────────────────────

generic=""
case "$event" in
sessionStart) generic="SessionStart" ;;
sessionEnd) generic="" ;; # handled separately
beforeSubmitPrompt) generic="PromptSubmit" ;;
preToolUse | beforeMCPExecution | beforeShellExecution | subagentStart) generic="ToolStart" ;;
afterAgentResponse | afterAgentThought | subagentStop) generic="ToolEnd" ;;
stop) generic="TurnComplete" ;;
*) generic="" ;;
esac

# ── Resolve tmux pane identity ───────────────────────────────────────────

# Try session mapping first
[[ -z "${TMUX_PANE:-}" ]] && {
	pane="$(lookup_session_pane "$session_id")"
	[[ -n "$pane" ]] && export TMUX_PANE="$pane"
}

# Try conversation_id mapping
[[ -z "${TMUX_PANE:-}" ]] && {
	pane="$(lookup_session_pane "$conversation_id")"
	[[ -n "$pane" ]] && export TMUX_PANE="$pane"
}

# Try PID detection
[[ -z "${TMUX_PANE:-}" ]] && {
	pane="$(detect_tmux_pane_from_pid "$(find_cursor_agent_pid)")"
	[[ -n "$pane" ]] && export TMUX_PANE="$pane"
}

# Store mapping for future events
if [[ -n "${TMUX_PANE:-}" ]]; then
	[[ -n "$session_id" ]] && store_session_pane "$session_id" "$TMUX_PANE"
	[[ -n "$conversation_id" && "$conversation_id" != "$session_id" ]] && store_session_pane "$conversation_id" "$TMUX_PANE"
fi

# Fallback: use AGENT_MONITOR_INSTANCE_ID
if [[ -z "${TMUX_PANE:-}" && -z "${AGENT_MONITOR_INSTANCE_ID:-}" ]]; then
	if [[ -n "$cwd" ]]; then
		export AGENT_MONITOR_INSTANCE_ID="cursor-$(basename "$cwd")"
	elif [[ -n "$session_id" ]]; then
		export AGENT_MONITOR_INSTANCE_ID="cursor-$(sanitize_id "$session_id")"
	else
		exit 0 # can't identify, skip
	fi
fi

# ── Handle sessionEnd ────────────────────────────────────────────────────

if [[ "$event" == "sessionEnd" ]]; then
	# Clean up session mapping
	clear_session_mapping "$session_id"
	clear_session_mapping "$conversation_id"

	# Remove from agent-monitor state
	inst_id="${AGENT_MONITOR_INSTANCE_ID:-${TMUX_PANE:-}}"
	[[ -n "$inst_id" ]] && "$BIN" remove "$inst_id" 2>/dev/null || true
	exit 0
fi

# ── Post-stop grace period ──────────────────────────────────────────────
# Avoid flapping: if we just saw a TurnComplete, skip redundant events briefly.

inst_id="${AGENT_MONITOR_INSTANCE_ID:-${TMUX_PANE:-}}"
if [[ -n "$inst_id" && "$generic" != "SessionStart" ]]; then
	current_state="$("$BIN" state --json 2>/dev/null | jq -r --arg id "$inst_id" '.agents[$id].state // empty' 2>/dev/null)"
	if [[ "$current_state" == "needs-attention" || "$current_state" == "needs-help" ]]; then
		case "$generic" in
		PromptSubmit)
			turn_at="$("$BIN" state --json 2>/dev/null | jq -r --arg id "$inst_id" '.agents[$id].turn_completed_at // 0' 2>/dev/null)"
			now=$(date +%s)
			if [[ "$turn_at" =~ ^[0-9]+$ && "$((now - turn_at))" -le "$post_stop_grace_secs" ]]; then
				exit 0 # too soon after stop, skip
			fi
			;;
		ToolStart | ToolEnd)
			exit 0 # ignore tool events while in attention state
			;;
		esac
	fi
fi

# ── Reconcile ────────────────────────────────────────────────────────────

if [[ -n "$generic" ]]; then
	payload="$(jq -n --arg sid "$session_id" --arg cwd "$cwd" \
		'{session_id: $sid, cwd: $cwd}' 2>/dev/null)" || payload="$input"
	"$BIN" reconcile cursor "$generic" "$payload"
fi
