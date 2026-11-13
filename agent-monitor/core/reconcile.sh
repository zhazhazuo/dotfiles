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
#   SubagentsRunning              → subagents-running
#
# SubagentsRunning: the main agent is parked (its turn ended) while background
# subagents it spawned are still running. Distinct from needs-attention so the
# indicator is not read as "finished, review me" — no notification is sent.
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
	SubagentsRunning)
		printf 'subagents-running'
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

# The event fields, read in one pass. One jq call replaces one per field, and
# the unit separator keeps an empty field from shifting the ones after it.
parse_event() {
	printf '%s' "$1" | jq -r '
		[ (.pane_id // ""), (.session_id // ""), (.cwd // ""),
		  (.label // ""), ((.subagents // 0) | tostring) ]
		| join("\u001f")' 2>/dev/null || true
}

# Bash pattern substitution, so an identity costs no process to sanitize.
sanitize_id() {
	local id="${1//[^[:alnum:]_]/_}"
	while [[ "$id" == _* ]]; do id="${id#_}"; done
	while [[ "$id" == *_ ]]; do id="${id%_}"; done
	printf '%s' "$id"
}

resolve_id() {
	local agent_name="$1" pane_id="$2" session_id="$3" cwd="$4"

	# 1. Explicit override
	if [[ -n "${AGENT_MONITOR_INSTANCE_ID:-}" ]]; then
		sanitize_id "$AGENT_MONITOR_INSTANCE_ID"
		return 0
	fi

	# 2. TMUX_PANE
	if [[ -n "${TMUX_PANE:-}" ]]; then
		printf '%s' "$TMUX_PANE"
		return 0
	fi

	# 2.5. Explicit pane_id in event JSON (herdr, rex)
	if [[ -n "$pane_id" ]]; then
		sanitize_id "$pane_id"
		return 0
	fi

	# 3. session_id
	if [[ -n "$session_id" ]]; then
		sanitize_id "$session_id"
		return 0
	fi

	# 4. cwd basename
	if [[ -n "$cwd" ]]; then
		sanitize_id "${cwd##*/}"
		return 0
	fi

	# 5. agent name
	sanitize_id "$agent_name"
}

resolve_label() {
	local event_label="$1" cwd="$2"
	local label

	# Explicit label in event JSON wins (herdr tab label, rex session label)
	if [[ -n "$event_label" ]]; then
		printf '%s' "$event_label"
		return 0
	fi

	# Try tmux window name
	if [[ -n "${TMUX_PANE:-}" ]]; then
		label=$(tmux display-message -p -t "$TMUX_PANE" '#{window_name}' 2>/dev/null || true)
		if [[ -n "$label" && "$label" != "Window" ]]; then
			printf '%s' "$label"
			return 0
		fi
	fi

	# Fall back to cwd basename
	if [[ -n "$cwd" ]]; then
		printf '%s' "${cwd##*/}"
		return 0
	fi

	printf 'agent'
}

# ── Main Reconcile ──────────────────────────────────────────────────────

reconcile() {
	local agent_name="$1"
	local event_name="$2"
	local json="${3:-{\}}"
	local fields pane_id session_id cwd event_label subagents

	# One parse for every field the reconcile reads.
	fields=$(parse_event "$json")
	IFS=$'\x1f' read -r pane_id session_id cwd event_label subagents <<<"$fields"
	[[ "$subagents" =~ ^[0-9]+$ ]] || subagents=0

	# Reject subagent sessions
	if is_subagent_session "$session_id"; then
		return 0
	fi

	# Map event to state
	local new_state
	new_state=$(map_event_to_state "$agent_name" "$event_name" "$json")

	# Resolve identity
	local id label
	id=$(resolve_id "$agent_name" "$pane_id" "$session_id" "$cwd")
	label=$(resolve_label "$event_label" "$cwd")

	# Get current state for transition detection
	local prev_state
	prev_state=$(get_field "$id" "state")

	# Skip if state unchanged and stable
	if [[ "$prev_state" == "$new_state" ]] && [[ -n "$prev_state" ]]; then
		# A parked main agent still needs its heartbeat refreshed: the subagent
		# publisher republishes its labels every 45s, and prune uses the heartbeat
		# to tell a live wait from an abandoned one.
		if [[ "$new_state" == "subagents-running" ]]; then
			touch_subagents "$id" "$subagents"
		fi
		return 0
	fi

	# Apply state transition
	upsert_agent "$id" \
		"name=$agent_name" \
		"state=$new_state" \
		"label=$label" \
		"pane=${TMUX_PANE:-$pane_id}" \
		"session_id=$session_id" \
		"seen=0"

	# Subagent bookkeeping is numeric, so it bypasses the string-only upsert.
	if [[ "$new_state" == "subagents-running" ]]; then
		touch_subagents "$id" "$subagents"
	elif [[ "$prev_state" == "subagents-running" ]]; then
		clear_subagents "$id"
	fi

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
