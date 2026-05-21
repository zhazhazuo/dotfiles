#!/usr/bin/env bash
#
# Print a tmux topbar widget for AI agent panes.
#
# Widget parts:
#   1. Agent list: session name + window name for every detected agent pane.
#
# Detection order:
#   1. Explicit pane options: @agent_name / @agent_state
#   2. Heuristic process + pane-text detection using @agent_status_harnesses
#
# Explicit state contract:
#   tmux set-option -p -t "$TMUX_PANE" @agent_name codex
#   tmux set-option -p -t "$TMUX_PANE" @agent_state running
#   tmux set-option -p -t "$TMUX_PANE" @agent_instances 1

set -euo pipefail

tmux_global_option() {
	tmux show-options -gqv "$1" 2>/dev/null || true
}

tmux_pane_option() {
	local pane_id="$1"
	local option="$2"

	tmux show-options -pqv -t "$pane_id" "$option" 2>/dev/null || true
}

option_or_default() {
	local option="$1"
	local default="$2"
	local value

	value="$(tmux_global_option "$option")"
	printf '%s' "${value:-$default}"
}

word_option_or_default() {
	local option="$1"
	local default="$2"

	option_or_default "$option" "$default" | tr ',;' '  '
}

lower() {
	tr '[:upper:]' '[:lower:]'
}

matches_any() {
	local text="$1"
	local pattern="$2"

	printf '%s\n' "$text" | grep -Eiq "$pattern"
}

regex_escape() {
	printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\]/\\&/g'
}

normalize_state() {
	local state

	state="$(printf '%s' "${1:-agent}" | lower | tr '_' '-')"

	case "$state" in
	run | running | doing | work | working | busy | thinking | executing | tool | tools)
		printf 'doing'
		;;
	wait | waiting | idle | ready | done | complete | completed)
		printf 'waiting'
		;;
	input | needsinput | needs-input | confirm | approval | blocked)
		printf 'needs-input'
		;;
	fail | failed | failure | error)
		printf 'failed'
		;;
	*)
		printf 'agent'
		;;
	esac
}

color_for_state() {
	local state="$1"

	case "$state" in
	doing)
		tmux_global_option @thm_green
		;;
	needs-input)
		tmux_global_option @thm_blue
		;;
	*)
		tmux_global_option @thm_overlay_0
		;;
	esac
}

detect_agent_from_processes() {
	local pane_tty="$1"
	local pane_command="$2"
	local harnesses="$3"
	local tty_name processes haystack harness escaped pattern

	tty_name="${pane_tty#/dev/}"
	processes=""

	if [[ -n "$tty_name" ]]; then
		processes="$(ps -t "$tty_name" -o comm= -o command= 2>/dev/null || true)"
	fi

	haystack="$pane_command
$processes"

	for harness in $harnesses; do
		escaped="$(regex_escape "$harness")"
		pattern="(^|[[:space:]/])${escaped}([[:space:]]|$)"

		if [[ "$pane_command" == "$harness" ]] || matches_any "$haystack" "$pattern"; then
			printf '%s' "$harness"
			return 0
		fi
	done

	return 1
}

count_agent_instances_from_processes() {
	local pane_tty="$1"
	local pane_command="$2"
	local harnesses="$3"
	local tty_name processes count harness escaped pattern

	tty_name="${pane_tty#/dev/}"
	processes=""
	count=0

	if [[ -n "$tty_name" ]]; then
		processes="$(ps -t "$tty_name" -o comm= -o command= 2>/dev/null || true)"
	fi

	for harness in $harnesses; do
		escaped="$(regex_escape "$harness")"
		pattern="(^|[[:space:]/])${escaped}([[:space:]]|$)"
		count=$((count + $(printf '%s\n' "$processes" | grep -Eic "$pattern" || true)))
	done

	if [[ "$count" -le 0 ]]; then
		for harness in $harnesses; do
			if [[ "$pane_command" == "$harness" ]]; then
				count=1
				break
			fi
		done
	fi

	if [[ "$count" -le 0 ]]; then
		count=1
	fi

	printf '%s' "$count"
}

detect_state_from_text() {
	local pane_id="$1"
	local text line

	text="$(tmux capture-pane -pJ -t "$pane_id" -S -80 2>/dev/null | tail -40 | lower || true)"

	if [[ -z "$text" ]]; then
		printf 'agent'
		return 0
	fi

	while IFS= read -r line; do
		if matches_any "$line" 'permission|approval|approve|confirm|continue\?|press enter|allow|deny|\by/n\b|\[y/n\]|waiting for (approval|input)'; then
			printf 'needs-input'
			return 0
		elif matches_any "$line" 'thinking|running|executing|editing|applying|reading|writing|searching|calling|tool|working|processing'; then
			printf 'doing'
			return 0
		elif matches_any "$line" 'waiting|idle|inactive|ready|done|completed|complete'; then
			printf 'waiting'
			return 0
		elif matches_any "$line" 'error|failed|failure|denied|blocked|exception'; then
			printf 'failed'
			return 0
		fi
	done < <(printf '%s\n' "$text" | awk '{ lines[NR] = $0 } END { for (i = NR; i >= 1; i--) print lines[i] }')

	printf 'agent'
}

detect_pane_state() {
	local pane_id="$1"
	local pane_tty="$2"
	local pane_command="$3"
	local harnesses="$4"
	local explicit_name explicit_state

	explicit_name="$(tmux_pane_option "$pane_id" @agent_name)"
	explicit_state="$(tmux_pane_option "$pane_id" @agent_state)"

	if [[ -n "$explicit_name" ]]; then
		normalize_state "${explicit_state:-agent}"
		return 0
	fi

	if ! detect_agent_from_processes "$pane_tty" "$pane_command" "$harnesses" >/dev/null; then
		return 1
	fi

	detect_state_from_text "$pane_id"
}

detect_pane_instances() {
	local pane_id="$1"
	local pane_tty="$2"
	local pane_command="$3"
	local harnesses="$4"
	local explicit_instances

	explicit_instances="$(tmux_pane_option "$pane_id" @agent_instances)"

	if [[ "$explicit_instances" =~ ^[0-9]+$ ]] && [[ "$explicit_instances" -gt 0 ]]; then
		printf '%s' "$explicit_instances"
		return 0
	fi

	count_agent_instances_from_processes "$pane_tty" "$pane_command" "$harnesses"
}

print_agent_item() {
	local bg="$1"
	local state="$2"
	local session_name="$3"
	local window_name="$4"
	local instance_count="$5"
	local color suffix

	color="$(color_for_state "$state")"
	suffix=""

	if [[ "$instance_count" -gt 1 ]]; then
		suffix="($instance_count)"
	fi

	printf '#[bg=%s,fg=%s] %s:%s%s' "$bg" "${color:-colour177}" "$session_name" "$window_name" "$suffix"
}

append_agent_item() {
	local state="$1"
	local session_name="$2"
	local window_name="$3"
	local instance_count="$4"

	agent_items+=("$(print_agent_item "$bg" "$state" "$session_name" "$window_name" "$instance_count")")
	agent_count=$((agent_count + 1))
}

scan_panes() {
	local panes pane_id pane_tty pane_command session_name window_name agent_state instance_count

	panes="$(tmux list-panes -a -F '#{pane_id}	#{pane_tty}	#{pane_current_command}	#{session_name}	#{window_name}' 2>/dev/null || true)"

	while IFS=$'\t' read -r pane_id pane_tty pane_command session_name window_name; do
		[[ -z "${pane_id:-}" ]] && continue

		if ! agent_state="$(detect_pane_state "$pane_id" "$pane_tty" "$pane_command" "$harnesses")"; then
			continue
		fi

		instance_count="$(detect_pane_instances "$pane_id" "$pane_tty" "$pane_command" "$harnesses")"
		append_agent_item "$agent_state" "$session_name" "$window_name" "$instance_count"
	done <<<"$panes"
}

print_status() {
	[[ "$agent_count" -le 0 ]] && return 0

	printf '%s' "${agent_items[*]}"
}

load_config() {
	enabled="$(option_or_default @agent_status_enabled on)"
	harnesses="$(word_option_or_default @agent_status_harnesses "pi opencode codex")"
	bg="$(option_or_default @thm_bg default)"
}

cache_file() {
	if [[ -n "${TMUX_AGENT_STATUS_CACHE:-}" ]]; then
		printf '%s' "$TMUX_AGENT_STATUS_CACHE"
		return 0
	fi

	printf '%s/tmux-agent-status.%s.cache' "${TMPDIR:-/tmp}" "${UID:-$(id -u)}"
}

refresh_status_cache() {
	local cache tmp

	cache="$(cache_file)"
	tmp="${cache}.$$"

	mkdir -p "$(dirname "$cache")"
	render_status >"$tmp"
	mv "$tmp" "$cache"
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

render_status() {
	local enabled harnesses bg
	local agent_items=() agent_count=0

	load_config

	if [[ "$enabled" == "off" || "$enabled" == "false" || "$enabled" == "0" ]]; then
		return 0
	fi

	scan_panes
	print_status
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
