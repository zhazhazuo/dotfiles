#!/usr/bin/env bash
#
# Reconcile tmux agent monitor records from Codex hook events.

set +e +u

agent_name="${1:-agent}"
event_name="${2:-}"
input="$(cat 2>/dev/null || true)"

json_string_field() {
	local field="$1"

	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$input" | jq -r --arg field "$field" '.[$field] // empty' 2>/dev/null
	else
		printf '%s' "$input" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
	fi
}

json_query_string() {
	local query="$1"

	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$input" | jq -r "$query // empty" 2>/dev/null
	else
		printf ''
	fi
}

lowercase() {
	tr '[:upper:]' '[:lower:]'
}

sanitize_id() {
	tr -c '[:alnum:]_' '_' | sed 's/^_*//; s/_*$//'
}

tmux_global_option() {
	tmux show-options -gqv "$1" 2>/dev/null || true
}

tmux_set_global_option() {
	tmux set-option -gq "$1" "$2" 2>/dev/null || true
}

refresh_status() {
	local script_dir

	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
	"${script_dir}/agent-status.sh" --refresh >/dev/null 2>&1 || true
	tmux refresh-client -S 2>/dev/null || true
}

prune_stale_instances() {
	local script_dir

	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
	"${script_dir}/agent-monitor-prune.sh" >/dev/null 2>&1 || true
}

notify_if_attention_transition() {
	local previous_state="$1"
	local next_state="$2"
	local label="$3"
	local script_dir

	[[ "$previous_state" == "$next_state" ]] && return 0
	case "$next_state" in
	needs-help|needs-attention)
		script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
		"${script_dir}/agent-monitor-notify.sh" "$agent_name" "$next_state" "$label" >/dev/null 2>&1 || true
		;;
	esac
}

instance_id() {
	local raw_id cwd

	raw_id="${AGENT_MONITOR_INSTANCE_ID:-}"
	[[ -z "$raw_id" ]] && raw_id="${TMUX_PANE:-}"
	[[ -z "$raw_id" ]] && raw_id="$(json_string_field session_id)"
	if [[ -z "$raw_id" ]]; then
		cwd="$(json_string_field cwd)"
		[[ -n "$cwd" ]] && raw_id="$(basename "$cwd")"
	fi
	[[ -z "$raw_id" ]] && raw_id="$agent_name"

	printf '%s' "$raw_id" | sanitize_id
}

window_label() {
	local label cwd

	if [[ -n "${TMUX_PANE:-}" ]]; then
		label="$(tmux display-message -p -t "$TMUX_PANE" '#{window_name}' 2>/dev/null || true)"
	fi

	if [[ -z "$label" || "$label" == "Window" ]]; then
		cwd="$(json_string_field cwd)"
		if [[ -n "$cwd" ]]; then
			label="$(basename "$cwd")"
		fi
	fi

	printf '%s' "${label:-agent}"
}

state_for_event() {
	local tool_name sandbox_permissions

	tool_name="$(json_string_field tool_name | lowercase)"
	sandbox_permissions="$(json_query_string '.tool_input.sandbox_permissions' | lowercase)"

	case "$event_name" in
	SessionStart)
		printf 'idle'
		;;
	UserPromptSubmit|PostToolUse)
		printf 'running'
		;;
	PreToolUse)
		case "$tool_name" in
		*request_user_input*|*ask_question*|*ask_user*|*request_plugin_install*|*request_permission*|*request_approval*)
			printf 'needs-help'
			;;
		*)
			if [[ "$sandbox_permissions" == "require_escalated" ]]; then
				printf 'needs-help'
			else
				printf 'running'
			fi
			;;
		esac
		;;
	PermissionRequest)
		printf 'needs-help'
		;;
	Stop)
		printf 'needs-attention'
		;;
	*)
		printf 'idle'
		;;
	esac
}

reconcile_instance_list() {
	local id="$1"
	local instances item next seen_id=false

	instances="$(tmux_global_option @agent_monitor_instances)"
	for item in $instances; do
		[[ "$item" == "$id" ]] && seen_id=true
		case " $next " in
		*" $item "*)
			;;
		*)
			next="${next:+$next }$item"
			;;
		esac
	done

	if [[ "$seen_id" != true ]]; then
		next="${next:+$next }$id"
	fi

	tmux_set_global_option @agent_monitor_instances "$next"
}

main() {
	local id state label session_id now prefix current_state

	id="$(instance_id)"
	[[ -z "$id" ]] && id="$agent_name"

	state="$(state_for_event)"
	label="$(window_label)"
	session_id="$(json_string_field session_id)"
	now="${AGENT_MONITOR_NOW:-$(date +%s)}"
	prefix="@agent_monitor_${id}"

	prune_stale_instances
	reconcile_instance_list "$id"
	tmux_set_global_option "${prefix}_name" "$agent_name"
	current_state="$(tmux_global_option "${prefix}_state")"
	if [[ "$current_state" != "$state" ]]; then
		tmux_set_global_option "${prefix}_state" "$state"
	fi
	tmux_set_global_option "${prefix}_label" "$label"
	tmux_set_global_option "${prefix}_pane" "${TMUX_PANE:-}"
	tmux_set_global_option "${prefix}_session_id" "$session_id"
	tmux_set_global_option "${prefix}_updated_at" "$now"
	notify_if_attention_transition "$current_state" "$state" "$label"
	refresh_status
}

main
exit 0
