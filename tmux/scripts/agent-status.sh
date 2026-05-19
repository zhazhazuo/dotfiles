#!/usr/bin/env bash
#
# Print a tmux topbar widget for AI agent panes.
#
# Widget parts:
#   1. Agent state summary: icon + count per state.
#   2. Attention list: icon + session name + window name for panes needing involvement.
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

color_for_state() {
	local state="$1"

	case "$state" in
	doing)
		tmux_global_option @thm_green
		;;
	waiting)
		tmux_global_option @thm_yellow
		;;
	needs-input)
		tmux_global_option @thm_yellow
		;;
	failed)
		tmux_global_option @thm_red
		;;
	*)
		tmux_global_option @thm_mauve
		;;
	esac
}

icon_for_state() {
	local state="$1"
	local icon

	case "$state" in
	doing)
		icon="$(tmux_global_option @task_icon_busy)"
		printf '%s' "${icon:-󱚣 }"
		;;
	waiting)
		icon="$(tmux_global_option @task_icon_wait)"
		printf '%s' "${icon:-󰮥 }"
		;;
	needs-input)
		icon="$(tmux_global_option @task_icon_input)"
		printf '%s' "${icon:-󰀦 }"
		;;
	failed)
		icon="$(tmux_global_option @task_icon_fail)"
		printf '%s' "${icon:- }"
		;;
	*)
		printf '🤖 '
		;;
	esac
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

print_state_count() {
	local bg="$1"
	local state="$2"
	local count="$3"
	local color icon

	[[ "$count" -le 0 ]] && return 0

	color="$(color_for_state "$state")"
	icon="$(icon_for_state "$state")"

	color="${color:-colour177}"
	icon="${icon:-🤖 }"

	printf '#[bg=%s,fg=%s] %s%s ' "$bg" "$color" "$icon" "$count"
}

print_attention_item() {
	local bg="$1"
	local state="$2"
	local session_name="$3"
	local window_name="$4"
	local color icon

	color="$(color_for_state "$state")"
	icon="$(icon_for_state "$state")"

	color="${color:-colour177}"
	icon="${icon:-🤖 }"

	printf '#[bg=%s,fg=%s] %s%s:%s ' "$bg" "$color" "$icon" "$session_name" "$window_name"
}

main() {
	local enabled harnesses involve_states list_limit bg overlay
	local pane_id pane_tty pane_command session_name window_name
	local explicit_name explicit_state agent_state
	local doing_count=0 waiting_count=0 input_count=0 failed_count=0 agent_count=0 total_count=0
	local attention_items=() attention_count=0
	local panes

	enabled="$(tmux_global_option @agent_status_enabled)"
	if [[ "$enabled" == "off" || "$enabled" == "false" || "$enabled" == "0" ]]; then
		exit 0
	fi

	harnesses="$(tmux_global_option @agent_status_harnesses)"
	harnesses="${harnesses:-pi opencode codex}"
	harnesses="$(printf '%s' "$harnesses" | tr ',;' '  ')"

	involve_states="$(tmux_global_option @agent_status_involve_states)"
	involve_states="${involve_states:-needs-input failed}"
	involve_states="$(printf '%s' "$involve_states" | tr ',;' '  ')"

	list_limit="$(tmux_global_option @agent_status_list_limit)"
	list_limit="${list_limit:-4}"

	bg="$(tmux_global_option @thm_bg)"
	overlay="$(tmux_global_option @thm_overlay_0)"
	bg="${bg:-default}"
	overlay="${overlay:-colour244}"

	panes="$(tmux list-panes -a -F '#{pane_id}	#{pane_tty}	#{pane_current_command}	#{session_name}	#{window_name}' 2>/dev/null || true)"

	while IFS=$'\t' read -r pane_id pane_tty pane_command session_name window_name; do
		[[ -z "${pane_id:-}" ]] && continue

		explicit_name="$(tmux_pane_option "$pane_id" @agent_name)"
		explicit_state="$(tmux_pane_option "$pane_id" @agent_state)"

		if [[ -n "$explicit_name" ]]; then
			agent_state="$(normalize_state "${explicit_state:-agent}")"
		else
			if ! detect_agent_from_processes "$pane_tty" "$pane_command" "$harnesses" >/dev/null; then
				continue
			fi

			agent_state="$(detect_state_from_text "$pane_id")"
		fi

		total_count=$((total_count + 1))

		case "$agent_state" in
		doing)
			doing_count=$((doing_count + 1))
			;;
		waiting)
			waiting_count=$((waiting_count + 1))
			;;
		needs-input)
			input_count=$((input_count + 1))
			;;
		failed)
			failed_count=$((failed_count + 1))
			;;
		*)
			agent_count=$((agent_count + 1))
			;;
		esac

		if contains_word "$involve_states" "$agent_state"; then
			if [[ "$attention_count" -lt "$list_limit" ]]; then
				attention_items+=("$(print_attention_item "$bg" "$agent_state" "$session_name" "$window_name")")
			fi
			attention_count=$((attention_count + 1))
		fi
	done <<<"$panes"

	[[ "$total_count" -le 0 ]] && exit 0

	printf '#[bg=%s,fg=%s] ' "$bg" "$overlay"
	print_state_count "$bg" doing "$doing_count"
	print_state_count "$bg" waiting "$waiting_count"
	print_state_count "$bg" needs-input "$input_count"
	print_state_count "$bg" failed "$failed_count"
	print_state_count "$bg" agent "$agent_count"

	if [[ "$attention_count" -gt 0 ]]; then
		printf '#[bg=%s,fg=%s]│ ' "$bg" "$overlay"
		printf '%s' "${attention_items[*]}"

		if [[ "$attention_count" -gt "$list_limit" ]]; then
			printf '#[bg=%s,fg=%s]+%s ' "$bg" "$overlay" "$((attention_count - list_limit))"
		fi
	fi

	printf '#[bg=%s,fg=%s]│' "$bg" "$overlay"
}

main
