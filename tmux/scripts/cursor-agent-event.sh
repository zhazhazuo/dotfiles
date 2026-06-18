#!/usr/bin/env bash
#
# Adapter: Cursor hook events → tmux agent monitor generic events.
#
# Called by ~/.cursor/hooks/agent-monitor.sh with:
#   $1      = Cursor hook event name (e.g. "sessionStart", "preToolUse", "stop")
#   stdin   = the raw Cursor hook JSON payload

set +e +u # fail open — never break the host application

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
event="${1:-}"
agent_name="cursor"
post_stop_grace_secs=5

# ── Read the raw Cursor JSON from stdin ──────────────────────────────────
input="$(cat 2>/dev/null || true)"

sanitize_id() {
	printf '%s' "$1" | tr -c '[:alnum:]_' '_' | sed 's/^_*//; s/_*$//'
}

json_field() {
	local field="$1"

	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$input" | jq -r --arg field "$field" '.[$field] // empty' 2>/dev/null
	else
		printf '%s' "$input" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
	fi
}

session_option_key() {
	local field="$1"
	printf '@cursor_agent_session_%s_%s' "$(sanitize_id "$2")" "$field"
}

lookup_session_pane() {
	local sid="$1"

	[[ -z "$sid" ]] && return 1
	tmux show-options -gqv "$(session_option_key pane "$sid")" 2>/dev/null || true
}

store_session_pane() {
	local sid="$1"
	local pane="$2"

	[[ -z "$sid" || -z "$pane" ]] && return 0
	tmux set-option -gq "$(session_option_key pane "$sid")" "$pane" 2>/dev/null || true
}

clear_session_mapping() {
	local sid="$1"

	[[ -z "$sid" ]] && return 0
	tmux set-option -guq "$(session_option_key pane "$sid")" 2>/dev/null || true
}

store_session_aliases() {
	local pane="$1"
	local sid conversation_id

	sid="${2:-}"
	conversation_id="${3:-}"
	[[ -z "$pane" ]] && return 0
	[[ -n "$sid" ]] && store_session_pane "$sid" "$pane"
	[[ -n "$conversation_id" && "$conversation_id" != "$sid" ]] && store_session_pane "$conversation_id" "$pane"
}

clear_session_aliases() {
	clear_session_mapping "${1:-}"
	clear_session_mapping "${2:-}"
}

resolve_session_pane() {
	local sid="$1"
	local conversation_id="$2"
	local pane=""

	pane="$(lookup_session_pane "$sid")"
	[[ -n "$pane" ]] && printf '%s' "$pane" && return 0

	[[ -n "$conversation_id" && "$conversation_id" != "$sid" ]] || return 1
	pane="$(lookup_session_pane "$conversation_id")"
	[[ -n "$pane" ]] && printf '%s' "$pane"
}

lookup_pane_by_monitor_session() {
	local sid="$1"
	local instances id stored_sid pane

	[[ -z "$sid" ]] && return 1
	instances="$(tmux show-options -gqv @agent_monitor_instances 2>/dev/null || true)"
	for id in $instances; do
		stored_sid="$(tmux show-options -gqv "@agent_monitor_${id}_session_id" 2>/dev/null || true)"
		if [[ "$stored_sid" == "$sid" ]]; then
			pane="$(tmux show-options -gqv "@agent_monitor_${id}_pane" 2>/dev/null || true)"
			[[ -n "$pane" ]] && printf '%s' "$pane" && return 0
		fi
	done

	return 1
}

lookup_pane_by_cwd() {
	local target_cwd="$1"
	local pane pane_cwd

	[[ -z "$target_cwd" ]] && return 1
	if ! command -v tmux >/dev/null 2>&1; then
		return 1
	fi

	while IFS= read -r pane; do
		[[ -z "$pane" ]] && continue
		pane_cwd="$(tmux display-message -p -t "$pane" '#{pane_current_path}' 2>/dev/null || true)"
		if [[ "$pane_cwd" == "$target_cwd" ]]; then
			printf '%s' "$pane"
			return 0
		fi
	done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)

	return 1
}

run_monitor() {
	local generic="$1"
	local payload="$2"

	printf '%s' "${payload:-{\}}" | "$script_dir/agent-monitor-check.sh" "$agent_name" "$generic" >/dev/null 2>&1 || true
}

run_delete() {
	local inst_id="$1"

	[[ -z "$inst_id" ]] && return 0
	"$script_dir/agent-monitor-delete-items.sh" "$inst_id" >/dev/null 2>&1 || true
}

# ── Map Cursor hook events to generic events ──────────────────────────────
generic=""
case "$event" in
sessionStart) generic="SessionStart" ;;
sessionEnd) generic="" ;;
beforeSubmitPrompt) generic="PromptSubmit" ;;
preToolUse | beforeMCPExecution | beforeShellExecution | subagentStart)
	generic="ToolStart"
	;;
afterAgentResponse | afterAgentThought | subagentStop)
	generic="ToolEnd"
	;;
stop) generic="TurnComplete" ;;
*) generic="$event" ;;
esac

# ── Normalise Cursor JSON → monitor JSON ─────────────────────────────────
session_id="$(json_field session_id)"
conversation_id="$(json_field conversation_id)"
if command -v jq >/dev/null 2>&1; then
	cwd="$(printf '%s' "$input" | jq -r '.workspace_roots[0] // empty' 2>/dev/null)"
else
	cwd="$(printf '%s' "$input" | sed -n 's/.*"workspace_roots"[[:space:]]*:[[:space:]]*\[[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

# ── Detect the tmux pane for a cursor-agent CLI process ──────────────────
detect_tmux_pane_from_pid() {
	local agent_pid="$1"
	local agent_tty pane_lines pane_id

	[[ -z "$agent_pid" ]] && return 1
	agent_tty="$(ps -p "$agent_pid" -o tty= 2>/dev/null | tr -d ' ')"
	[[ -z "$agent_tty" || "$agent_tty" == "??" ]] && return 1

	if command -v tmux >/dev/null 2>&1; then
		pane_lines="$(tmux list-panes -a -F '#{pane_id} #{pane_tty}' 2>/dev/null)"
		pane_id="$(printf '%s\n' "$pane_lines" | grep "/dev/${agent_tty}$" | awk '{print $1}')"
		if [[ -n "$pane_id" ]]; then
			printf '%s' "$pane_id"
			return 0
		fi
	fi
	return 1
}

find_cursor_agent_pid() {
	local agent_pid

	agent_pid="$(pgrep -f 'cursor-agent/versions/' 2>/dev/null | tail -1)"
	[[ -n "$agent_pid" ]] && printf '%s' "$agent_pid" && return 0

	agent_pid="$(pgrep -f '\.local/bin/agent' 2>/dev/null | tail -1)"
	[[ -n "$agent_pid" ]] && printf '%s' "$agent_pid" && return 0

	agent_pid="$(pgrep -f '/cursor-agent/' 2>/dev/null | grep -v hooks | tail -1)"
	[[ -n "$agent_pid" ]] && printf '%s' "$agent_pid" && return 0

	return 1
}

detect_tmux_pane() {
	local agent_pid

	agent_pid="$(find_cursor_agent_pid)"
	detect_tmux_pane_from_pid "$agent_pid"
}

# ── Resolve identity ─────────────────────────────────────────────────────
stored_pane=""
stored_pane="$(resolve_session_pane "$session_id" "$conversation_id")"
[[ -n "$stored_pane" ]] && export TMUX_PANE="$stored_pane"

if [[ -z "${TMUX_PANE:-}" ]]; then
	stored_pane="$(lookup_pane_by_monitor_session "$session_id")"
	[[ -z "$stored_pane" ]] && stored_pane="$(lookup_pane_by_monitor_session "$conversation_id")"
	[[ -n "$stored_pane" ]] && export TMUX_PANE="$stored_pane"
fi

if [[ -z "${TMUX_PANE:-}" && -n "$cwd" ]]; then
	stored_pane="$(lookup_pane_by_cwd "$cwd")"
	[[ -n "$stored_pane" ]] && export TMUX_PANE="$stored_pane"
fi

detected_pane=""
if [[ -z "${TMUX_PANE:-}" ]]; then
	detected_pane="$(detect_tmux_pane)"
	[[ -n "$detected_pane" ]] && export TMUX_PANE="$detected_pane"
fi

if [[ "$event" == "sessionStart" && -n "${TMUX_PANE:-}" ]]; then
	store_session_aliases "$TMUX_PANE" "$session_id" "$conversation_id"
elif [[ -n "${TMUX_PANE:-}" ]]; then
	store_session_aliases "$TMUX_PANE" "$session_id" "$conversation_id"
fi

agent_is_dead=false
if [[ -z "${TMUX_PANE:-}" && -z "${AGENT_MONITOR_INSTANCE_ID:-}" ]]; then
	if [[ -n "$cwd" ]]; then
		export AGENT_MONITOR_INSTANCE_ID="cursor-$(basename "$cwd")"
	elif [[ -n "$session_id" ]]; then
		export AGENT_MONITOR_INSTANCE_ID="cursor-$(sanitize_id "$session_id")"
	else
		agent_is_dead=true
	fi
fi

if [[ "$agent_is_dead" == true ]]; then
	exit 0
fi

monitor_instance_id() {
	local inst_id=""

	inst_id="${AGENT_MONITOR_INSTANCE_ID:-${TMUX_PANE:-}}"
	[[ -z "$inst_id" && -n "$session_id" ]] && inst_id="$(sanitize_id "$session_id")"
	[[ -z "$inst_id" && -n "$cwd" ]] && inst_id="$(basename "$cwd")"
	[[ -z "$inst_id" ]] && inst_id="$agent_name"
	sanitize_id "$inst_id"
}

if [[ "$event" == "sessionEnd" ]]; then
	run_delete "$(monitor_instance_id)"
	clear_session_aliases "$session_id" "$conversation_id"
	exit 0
fi

if [[ -n "$cwd" || -n "$session_id" ]]; then
	payload="$(jq -n --arg sid "$session_id" --arg cwd "$cwd" \
		'{session_id: $sid, cwd: $cwd}' 2>/dev/null)" || payload="$input"
else
	payload="$input"
fi

skip_event=false
if command -v tmux >/dev/null 2>&1 && [[ -n "$generic" ]]; then
	inst_id="$(monitor_instance_id)"
	current_st="$(tmux show-options -gqv "@agent_monitor_${inst_id}_state" 2>/dev/null || true)"
	case "$current_st" in
	needs-attention | needs-help)
		case "$generic" in
		SessionStart | TurnComplete | ToolStart | RunStart | ToolEnd) ;;
		PromptSubmit)
			last_turn="$(tmux show-options -gqv "@agent_monitor_${inst_id}_turn_completed_at" 2>/dev/null || true)"
			now="${AGENT_MONITOR_NOW:-$(date +%s)}"
			if [[ -n "$last_turn" && "$last_turn" =~ ^[0-9]+$ && "$((now - last_turn))" -le "$post_stop_grace_secs" ]]; then
				skip_event=true
			fi
			;;
		*) skip_event=true ;;
		esac
		;;
	esac
fi

if [[ "$skip_event" != true && -n "$generic" ]]; then
	run_monitor "$generic" "$payload"
fi

exit 0
