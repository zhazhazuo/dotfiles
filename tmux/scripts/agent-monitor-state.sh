#!/usr/bin/env bash
#
# Export tmux agent monitor records to a small shared state file for other UI
# surfaces such as SketchyBar.

set -euo pipefail

tmux_global_option() {
	tmux show-options -gqv "$1" 2>/dev/null || true
}

state_file() {
	if [[ -n "${AGENT_MONITOR_STATE_FILE:-}" ]]; then
		printf '%s' "$AGENT_MONITOR_STATE_FILE"
		return 0
	fi

	printf '%s/agent-monitor/agent-monitor.%s.tsv' "${XDG_CACHE_HOME:-${HOME}/.cache}" "${UID:-$(id -u)}"
}

normalize_field() {
	printf '%s' "${1:-}" | tr '\t\r\n' '   '
}

is_integer() {
	[[ "${1:-}" =~ ^[0-9]+$ ]]
}

current_epoch() {
	printf '%s' "${AGENT_MONITOR_STATE_NOW:-$(date +%s)}"
}

option_or_default() {
	local option="$1"
	local default="$2"
	local value

	value="$(tmux_global_option "$option")"
	printf '%s' "${value:-$default}"
}

effective_state() {
	local state="$1"
	local updated_at="$2"
	local now="$3"
	local attention_timeout="$4"

	if [[ "$state" == "needs-attention" ]] && is_integer "$updated_at" && is_integer "$attention_timeout"; then
		if [[ "$((now - updated_at))" -gt "$attention_timeout" ]]; then
			printf 'idle'
			return 0
		fi
	fi

	printf '%s' "$state"
}

write_state() {
	local file tmp instances id prefix name state label pane session_id updated_at now attention_timeout

	file="$(state_file)"
	tmp="${file}.$$"
	instances="$(tmux_global_option @agent_monitor_instances)"
	now="$(current_epoch)"
	attention_timeout="$(option_or_default @agent_monitor_attention_timeout 300)"

	mkdir -p "$(dirname "$file")"
	printf 'id\tname\tstate\tlabel\tpane\tsession_id\tupdated_at\n' >"$tmp"

	for id in $instances; do
		prefix="@agent_monitor_${id}"
		name="$(tmux_global_option "${prefix}_name")"
		state="$(tmux_global_option "${prefix}_state")"
		label="$(tmux_global_option "${prefix}_label")"
		pane="$(tmux_global_option "${prefix}_pane")"
		session_id="$(tmux_global_option "${prefix}_session_id")"
		updated_at="$(tmux_global_option "${prefix}_updated_at")"

		[[ -z "$name" && -z "$state" && -z "$label" ]] && continue
		state="$(effective_state "${state:-idle}" "$updated_at" "$now" "$attention_timeout")"

		printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$(normalize_field "$id")" \
			"$(normalize_field "$name")" \
			"$(normalize_field "$state")" \
			"$(normalize_field "$label")" \
			"$(normalize_field "$pane")" \
			"$(normalize_field "$session_id")" \
			"$(normalize_field "$updated_at")" >>"$tmp"
	done

	mv "$tmp" "$file"
}

trigger_sketchybar() {
	if [[ -n "${AGENT_MONITOR_SKIP_SKETCHYBAR:-}" ]]; then
		return 0
	fi

	if command -v sketchybar >/dev/null 2>&1; then
		(sketchybar --trigger agent_monitor_update >/dev/null 2>&1 || true) &
	fi
}

print_state() {
	local file

	file="$(state_file)"
	[[ -r "$file" ]] && cat "$file"
}

main() {
	case "${1:-}" in
	--refresh)
		write_state
		trigger_sketchybar
		;;
	--print|"")
		print_state
		;;
	*)
		printf 'Usage: %s [--refresh|--print]\n' "$0" >&2
		return 2
		;;
	esac
}

main "$@"
