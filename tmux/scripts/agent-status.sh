#!/usr/bin/env bash
#
# Print a tmux topbar widget for AI agent panes.
#
# Widget parts:
#   1. Attention list: icon + session name + window name for panes needing involvement.
#
# Detection order:
#   1. Explicit pane options: @agent_name / @agent_state
#   2. Heuristic process + pane-text detection using @agent_status_harnesses
#
# Explicit state example:
#   tmux set-option -p -t "$TMUX_PANE" @agent_name pi
#   tmux set-option -p -t "$TMUX_PANE" @agent_state doing

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

contains_word() {
	local words="$1"
	local needle="$2"
	local word

	for word in $words; do
		[[ "$word" == "$needle" ]] && return 0
	done

	return 1
}

normalize_state() {
	local state

	state="$(printf '%s' "${1:-agent}" | lower | tr '_' '-')"

	case "$state" in
	run | running | work | working | busy | thinking | executing | tool | tools)
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
	waiting)
		tmux_global_option @thm_blue
		# tmux_global_option @thm_yellow
		;;
	needs-input)
		tmux_global_option @thm_blue
		;;
	failed)
		tmux_global_option @thm_blue
		;;
	*)
		tmux_global_option @thm_mauve
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

detect_state_from_text() {
	local pane_id="$1"
	local text

	text="$(tmux capture-pane -pJ -t "$pane_id" -S -80 2>/dev/null | tail -40 | lower || true)"

	if [[ -z "$text" ]]; then
		printf 'agent'
		return 0
	fi

	if matches_any "$text" 'permission|approval|approve|confirm|continue\?|press enter|allow|deny|\by/n\b|\[y/n\]|waiting for (approval|input)'; then
		printf 'needs-input'
	elif matches_any "$text" 'error|failed|failure|denied|blocked|exception'; then
		printf 'failed'
	elif matches_any "$text" 'thinking|running|executing|editing|applying|reading|writing|searching|calling|tool|working|processing'; then
		printf 'doing'
	elif matches_any "$text" 'waiting|idle|ready|done|completed|complete'; then
		printf 'waiting'
	else
		printf 'agent'
	fi
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

print_attention_item() {
	local bg="$1"
	local state="$2"
	local session_name="$3"
	local window_name="$4"
	local color

	color="$(color_for_state "$state")"

	printf '#[bg=%s,fg=%s] %s:%s' "$bg" "${color:-colour177}" "$session_name" "$window_name"
}

append_attention_item() {
	local state="$1"
	local session_name="$2"
	local window_name="$3"

	if ! contains_word "$involve_states" "$state"; then
		return 0
	fi

	attention_items+=("$(print_attention_item "$bg" "$state" "$session_name" "$window_name")")
	attention_count=$((attention_count + 1))
}

scan_panes() {
	local panes pane_id pane_tty pane_command session_name window_name agent_state

	panes="$(tmux list-panes -a -F '#{pane_id}	#{pane_tty}	#{pane_current_command}	#{session_name}	#{window_name}' 2>/dev/null || true)"

	while IFS=$'\t' read -r pane_id pane_tty pane_command session_name window_name; do
		[[ -z "${pane_id:-}" ]] && continue

		if ! agent_state="$(detect_pane_state "$pane_id" "$pane_tty" "$pane_command" "$harnesses")"; then
			continue
		fi

		append_attention_item "$agent_state" "$session_name" "$window_name"
	done <<<"$panes"
}

print_status() {
	[[ "$attention_count" -le 0 ]] && return 0

	printf '%s' "${attention_items[*]}"
}

load_config() {
	enabled="$(option_or_default @agent_status_enabled on)"
	harnesses="$(word_option_or_default @agent_status_harnesses "pi opencode codex")"
	involve_states="$(word_option_or_default @agent_status_involve_states "needs-input failed")"
	bg="$(option_or_default @thm_bg default)"
}

main() {
	local enabled harnesses involve_states bg
	local attention_items=() attention_count=0

	load_config

	if [[ "$enabled" == "off" || "$enabled" == "false" || "$enabled" == "0" ]]; then
		exit 0
	fi

	scan_panes
	print_status
}

main
