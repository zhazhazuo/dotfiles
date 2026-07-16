#!/usr/bin/env bash
#
# agent-monitor/core/reconcile.sh — Event → state transition
#
# Maps agent events to monitor states and updates the store.
# Called by: agent-monitor reconcile <agent-name> <event-name> '<json>'
#
# Event mapping (agent-agnostic generic):
#   SessionStart/SessionResume    → idle
#   PromptSubmit/RunStart/Tool*   → running
#   PermissionRequest/InputRequired → needs-help
#   TurnComplete/Stop             → needs-attention
#
# Agent-specific overrides only when legacy event names differ.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/state.sh"

# ── Event → State Mapping ────────────────────────────────────────────────

map_event_to_state() {
	local agent_name="$1"
	local event_name="$2"

	# Agent-agnostic generic mapping (preferred)
	case "$event_name" in
	SessionStart | SessionResume)
		printf 'idle'
		return 0
		;;
	PromptSubmit | RunStart | ToolStart | ToolEnd)
		printf 'running'
		return 0
		;;
	PermissionRequest | InputRequired)
		printf 'needs-help'
		return 0
		;;
	TurnComplete | Stop)
		printf 'needs-attention'
		return 0
		;;
	esac

	# Codex-specific legacy mapping
	if [[ "$agent_name" == "codex" ]]; then
		case "$event_name" in
		UserPromptSubmit | PostToolUse)
			printf 'running'
			return 0
			;;
		PreToolUse)
			# Check for permission-requiring tools
			local tool_name
			tool_name=$(printf '%s' "$3" | jq -r '.tool_name // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]')
			case "$tool_name" in
			*request_user_input* | *ask_question* | *ask_user* | *request_permission* | *request_approval*)
				printf 'needs-help'
				;;
			*)
				printf 'running'
				;;
			esac
			return 0
			;;
		PermissionRequest)
			printf 'needs-help'
			return 0
			;;
		esac
	fi

	# Pi-specific legacy mapping
	if [[ "$agent_name" == "pi" ]]; then
		case "$event_name" in
		AgentStart)
			printf 'running'
			return 0
			;;
		AgentEnd)
			printf 'needs-attention'
			return 0
			;;
		SessionShutdown)
			printf 'idle'
			return 0
			;;
		esac
	fi

	# Default: unknown events → idle
	printf 'idle'
}

# ── Subagent Detection ──────────────────────────────────────────────────

is_subagent_session() {
	local session_id="$1"
	printf '%s' "$session_id" | grep -qE '/run-[0-9]+/session\.jsonl$'
}

# ── Identity Resolution ─────────────────────────────────────────────────

resolve_id() {
	local agent_name="$1" json="$2"
	local id

	# 1. Explicit override
	if [[ -n "${AGENT_MONITOR_INSTANCE_ID:-}" ]]; then
		printf '%s' "$AGENT_MONITOR_INSTANCE_ID" | tr -c '[:alnum:]_' '_'
		return 0
	fi

	# 2. TMUX_PANE
	if [[ -n "${TMUX_PANE:-}" ]]; then
		printf '%s' "$TMUX_PANE"
		return 0
	fi

	# 3. session_id
	local session_id
	session_id=$(printf '%s' "$json" | jq -r '.session_id // empty' 2>/dev/null)
	if [[ -n "$session_id" ]]; then
		printf '%s' "$session_id" | tr -c '[:alnum:]_' '_' | sed 's/^_*//; s/_*$//'
		return 0
	fi

	# 4. cwd basename
	local cwd
	cwd=$(printf '%s' "$json" | jq -r '.cwd // empty' 2>/dev/null)
	if [[ -n "$cwd" ]]; then
		basename "$cwd" | tr -c '[:alnum:]_' '_'
		return 0
	fi

	# 5. agent name
	printf '%s' "$agent_name" | tr -c '[:alnum:]_' '_'
}

resolve_label() {
	local json="$1"
	local label

	# Try tmux window name first
	if [[ -n "${TMUX_PANE:-}" ]]; then
		label=$(tmux display-message -p -t "$TMUX_PANE" '#{window_name}' 2>/dev/null || true)
		if [[ -n "$label" && "$label" != "Window" ]]; then
			printf '%s' "$label"
			return 0
		fi
	fi

	# Fall back to cwd basename
	local cwd
	cwd=$(printf '%s' "$json" | jq -r '.cwd // empty' 2>/dev/null)
	if [[ -n "$cwd" ]]; then
		basename "$cwd"
		return 0
	fi

	printf 'agent'
}

# ── Main Reconcile ──────────────────────────────────────────────────────

reconcile() {
	local agent_name="$1"
	local event_name="$2"
	local json="${3:-{\}}"

	# Reject subagent sessions
	local session_id
	session_id=$(printf '%s' "$json" | jq -r '.session_id // empty' 2>/dev/null)
	if is_subagent_session "$session_id"; then
		return 0
	fi

	# Map event to state
	local new_state
	new_state=$(map_event_to_state "$agent_name" "$event_name" "$json")

	# Resolve identity
	local id label
	id=$(resolve_id "$agent_name" "$json")
	label=$(resolve_label "$json")

	# Get current state for transition detection
	local prev_state
	prev_state=$(get_field "$id" "state")

	# Skip if state unchanged and stable
	if [[ "$prev_state" == "$new_state" ]] && [[ -n "$prev_state" ]]; then
		return 0
	fi

	# Apply state transition
	upsert_agent "$id" \
		"name=$agent_name" \
		"state=$new_state" \
		"label=$label" \
		"pane=${TMUX_PANE:-}" \
		"session_id=$session_id"

	# Notify on attention transitions
	if [[ "$prev_state" != "$new_state" ]]; then
		case "$new_state" in
		needs-help | needs-attention)
			"${SCRIPT_DIR}/notify.sh" "$agent_name" "$new_state" "$label" 2>/dev/null || true
			;;
		esac
	fi

	# Refresh sinks
	refresh_sinks
}

# ── Sink Refresh ────────────────────────────────────────────────────────

refresh_sinks() {
	# Refresh tmux status if available
	local sinks_dir="${SCRIPT_DIR}/../sinks"

	if [[ -x "${sinks_dir}/tmux-status.sh" ]]; then
		"${sinks_dir}/tmux-status.sh" --refresh 2>/dev/null || true
	fi

	# Trigger SketchyBar update if available
	if command -v sketchybar >/dev/null 2>&1; then
		(sketchybar --trigger agent_monitor_update 2>/dev/null || true) &
	fi

	# Refresh tmux client
	tmux refresh-client -S 2>/dev/null || true
}
