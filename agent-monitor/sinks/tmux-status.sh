#!/usr/bin/env bash
#
# agent-monitor/sinks/tmux-status.sh — tmux topbar widget renderer
#
# Reads state.json and renders agent status into tmux's status line.
# Applies timeout decay for needs-attention state (display-only).
#
# Usage:
#   tmux-status.sh --once      # Print rendered status to stdout
#   tmux-status.sh --refresh   # Update tmux option + filesystem cache
#   tmux-status.sh             # Print cached status (fast path)

set -euo pipefail

# Resolve symlink to find actual script location
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
	DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
	SOURCE="$(readlink "$SOURCE")"
	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SINK_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
CORE_DIR="${SINK_DIR}/../core"

source "${CORE_DIR}/state.sh"

# ── Configuration ────────────────────────────────────────────────────────

tmux_global_option() {
	tmux show-options -gqv "$1" 2>/dev/null || true
}

option_or_default() {
	local option="$1" default="$2" value
	value=$(tmux_global_option "$option")
	printf '%s' "${value:-$default}"
}

ATTENTION_TIMEOUT=$(option_or_default @agent_monitor_attention_timeout 300)
BG=$(option_or_default @thm_bg default)
SEPARATOR_COLOR=$(option_or_default @thm_overlay_0 colour240)

# ── State → Color ────────────────────────────────────────────────────────

color_for_state() {
	case "$1" in
	running) tmux_global_option @thm_green ;;
	needs-help) tmux_global_option @thm_red ;;
	needs-attention) tmux_global_option @thm_blue ;;
	*) tmux_global_option @thm_overlay_0 ;;
	esac
}

# ── Timeout Decay ────────────────────────────────────────────────────────

effective_state() {
	local state="$1" updated_at="$2" now="$3"

	if [[ "$state" == "needs-attention" ]] && [[ "$updated_at" =~ ^[0-9]+$ ]]; then
		if [[ "$((now - updated_at))" -gt "$ATTENTION_TIMEOUT" ]]; then
			printf 'idle'
			return 0
		fi
	fi

	printf '%s' "$state"
}

# ── Render ───────────────────────────────────────────────────────────────

render_agent_item() {
	local pane="$1" state="$2" label="$3" now="$4" updated_at="$5"
	local color effective

	effective=$(effective_state "$state" "$updated_at" "$now")
	color=$(color_for_state "$effective")

	# Escape tmux format characters in label
	label=$(printf '%s' "${label:-agent}" | sed 's/#/##/g')

	if [[ "$effective" == "idle" ]]; then
		# Idle: gray text, no background
		if [[ -n "$pane" ]]; then
			printf '#[range=pane|%s]#[bg=%s,fg=%s] %s #[norange]' "$pane" "$BG" "${color:-colour240}" "$label"
		else
			printf '#[bg=%s,fg=%s] %s' "$BG" "${color:-colour240}" "$label"
		fi
	else
		# Active: colored text with optional pane link
		if [[ -n "$pane" ]]; then
			printf '#[range=pane|%s]#[bg=%s,fg=%s] %s #[norange]' "$pane" "$BG" "${color:-colour240}" "$label"
		else
			printf '#[bg=%s,fg=%s] %s' "$BG" "${color:-colour240}" "$label"
		fi
	fi
}

render_status() {
	local now agent_count=0 items=()
	local enabled

	enabled=$(option_or_default @agent_status_enabled on)
	if [[ "$enabled" == "off" || "$enabled" == "false" || "$enabled" == "0" ]]; then
		return 0
	fi

	now=$(date +%s)

	for id in $(list_agents); do
		local state label pane updated_at
		state=$(get_field "$id" "state")
		label=$(get_field "$id" "label")
		pane=$(get_field "$id" "pane")
		updated_at=$(get_field "$id" "updated_at")

		[[ -z "$state" ]] && continue

		items+=("$(render_agent_item "$pane" "$state" "$label" "$now" "$updated_at")")
		agent_count=$((agent_count + 1))
	done

	if [[ "$agent_count" -eq 0 ]]; then
		return 0
	fi

	# Print items with separator
	local separator="#[bg=${BG},fg=${SEPARATOR_COLOR},none]  "
	printf '%s' "${items[0]}"
	for item in "${items[@]:1}"; do
		printf '%s%s' "$separator" "$item"
	done
}

# ── Cache ────────────────────────────────────────────────────────────────

cache_file() {
	printf '%s/tmux-agent-monitor-status.%s.cache' "${TMPDIR:-/tmp}" "${UID:-$(id -u)}"
}

refresh_cache() {
	local cache tmp rendered

	cache=$(cache_file)
	tmp="${cache}.$$"
	rendered=$(render_status)

	mkdir -p "$(dirname "$cache")"
	printf '%s' "$rendered" >"$tmp"
	mv "$tmp" "$cache"

	# Also set tmux option for immediate display
	tmux set-option -gq @agent_monitor_status "$rendered" 2>/dev/null || true
}

print_cached() {
	local cache
	cache=$(cache_file)
	if [[ -r "$cache" ]]; then
		cat "$cache"
	fi
}

# ── Main ─────────────────────────────────────────────────────────────────

main() {
	case "${1:-}" in
	--once | -o)
		render_status
		;;
	--refresh | -r)
		refresh_cache
		;;
	*)
		print_cached
		;;
	esac
}

main "$@"
