#!/usr/bin/env bash
#
# Print the tmux topbar widget for explicit agent monitor records.

set -euo pipefail

tmux_global_option() {
	tmux show-options -gqv "$1" 2>/dev/null || true
}

tmux_set_global_option() {
	tmux set-option -gq "$1" "$2" 2>/dev/null || true
}

option_or_default() {
	local option="$1"
	local default="$2"
	local value

	value="$(tmux_global_option "$option")"
	printf '%s' "${value:-$default}"
}

is_integer() {
	[[ "${1:-}" =~ ^[0-9]+$ ]]
}

current_epoch() {
	printf '%s' "${AGENT_STATUS_NOW:-$(date +%s)}"
}

tmux_format_literal() {
	printf '%s' "$1" | sed 's/#/##/g'
}

valid_pane_id() {
	[[ "${1:-}" =~ ^%[0-9]+$ ]]
}

effective_state() {
	local state="$1"
	local updated_at="$2"
	local now="$3"

	if [[ "$state" == "needs-attention" ]] && is_integer "$updated_at" && is_integer "$attention_timeout"; then
		if [[ "$((now - updated_at))" -gt "$attention_timeout" ]]; then
			printf 'idle'
			return 0
		fi
	fi

	printf '%s' "$state"
}

color_for_state() {
	local state="$1"

	case "$state" in
	running)
		tmux_global_option @thm_green
		;;
	needs-help)
		tmux_global_option @thm_red
		;;
	needs-attention)
		tmux_global_option @thm_blue
		;;
	*)
		tmux_global_option @thm_overlay_0
		;;
	esac
}

print_agent_item() {
	local bg="$1"
	local state="$2"
	local name="$3"
	local label="$4"
	local pane="$5"
	local color

	: "$name"
	color="$(color_for_state "$state")"
	label="$(tmux_format_literal "${label:-agent}")"
	if [[ "$state" == "needs-help" ]]; then
		if valid_pane_id "$pane"; then
			printf '#[range=pane|%s]#[bg=%s,fg=%s,bold] ‹%s›#[norange]' "$pane" "$bg" "${color:-colour240}" "$label"
		else
			printf '#[bg=%s,fg=%s,bold] ‹%s›' "$bg" "${color:-colour240}" "$label"
		fi
		return 0
	fi

	if valid_pane_id "$pane"; then
		printf '#[range=pane|%s]#[bg=%s,fg=%s] ‹%s›#[norange]' "$pane" "$bg" "${color:-colour240}" "$label"
	else
		printf '#[bg=%s,fg=%s] ‹%s›' "$bg" "${color:-colour240}" "$label"
	fi
}

append_agent_item() {
	local id="$1"
	local prefix name state label pane updated_at now

	prefix="@agent_monitor_${id}"
	name="$(tmux_global_option "${prefix}_name")"
	state="$(tmux_global_option "${prefix}_state")"
	label="$(tmux_global_option "${prefix}_label")"
	pane="$(tmux_global_option "${prefix}_pane")"
	updated_at="$(tmux_global_option "${prefix}_updated_at")"
	now="$(current_epoch)"

	[[ -z "$name" && -z "$state" && -z "$label" ]] && return 0

	state="$(effective_state "${state:-idle}" "$updated_at" "$now")"
	agent_items+=("$(print_agent_item "$bg" "$state" "${name:-agent}" "${label:-agent}" "$pane")")
	agent_count=$((agent_count + 1))
}

load_config() {
	enabled="$(option_or_default @agent_status_enabled on)"
	instances="$(tmux_global_option @agent_monitor_instances)"
	attention_timeout="$(option_or_default @agent_monitor_attention_timeout 300)"
	bg="$(option_or_default @thm_bg default)"
	separator_color="$(option_or_default @thm_overlay_0 colour240)"
	agent_separator="$(option_or_default @agent_status_separator "│")"
}

print_status() {
	[[ "$agent_count" -le 0 ]] && return 0

	local item separator

	separator="#[bg=${bg},fg=${separator_color:-colour240},none]  "
	printf '%s' "${agent_items[0]}"
	for item in "${agent_items[@]:1}"; do
		printf '%s%s' "$separator" "$item"
	done
}

render_status() {
	local enabled instances attention_timeout bg separator_color agent_separator
	local agent_items=() agent_count=0
	local id

	load_config

	if [[ "$enabled" == "off" || "$enabled" == "false" || "$enabled" == "0" ]]; then
		return 0
	fi

	for id in $instances; do
		append_agent_item "$id"
	done

	print_status
}

cache_file() {
	if [[ -n "${TMUX_AGENT_STATUS_CACHE:-}" ]]; then
		printf '%s' "$TMUX_AGENT_STATUS_CACHE"
		return 0
	fi

	printf '%s/tmux-agent-status.%s.cache' "${TMPDIR:-/tmp}" "${UID:-$(id -u)}"
}

refresh_status_cache() {
	local cache tmp rendered

	cache="$(cache_file)"
	tmp="${cache}.$$"
	rendered="$(render_status)"

	mkdir -p "$(dirname "$cache")"
	printf '%s' "$rendered" >"$tmp"
	mv "$tmp" "$cache"
	tmux_set_global_option @agent_monitor_status "$rendered"
}

print_cached_status() {
	local cache

	cache="$(cache_file)"
	if [[ -r "$cache" ]]; then
		cat "$cache"
	fi
}

start_background_refresh() {
	local cache lock_dir

	cache="$(cache_file)"
	lock_dir="${cache}.lock"

	if mkdir "$lock_dir" 2>/dev/null; then
		(
			trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
			refresh_status_cache
		) >/dev/null 2>&1 &
	fi
}

main() {
	case "${1:-}" in
	--once)
		render_status
		;;
	--refresh)
		refresh_status_cache
		;;
	*)
		print_cached_status
		start_background_refresh
		;;
	esac
}

main "$@"
