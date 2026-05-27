#!/usr/bin/env bash
#
# Remove tmux agent monitor records whose backing pane or agent process is gone.

set +e +u

tmux_global_option() {
	tmux show-options -gqv "$1" 2>/dev/null || true
}

tmux_set_global_option() {
	tmux set-option -gq "$1" "$2" 2>/dev/null || true
}

tmux_unset_global_option() {
	tmux set-option -guq "$1" 2>/dev/null || true
}

live_panes() {
	tmux list-panes -a -F '#{pane_id}' 2>/dev/null || true
}

regex_escape() {
	printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\]/\\&/g'
}

pane_exists() {
	local pane="$1"

	[[ -z "$pane" ]] && return 0
	printf '%s\n' "$live_pane_ids" | grep -Fxq "$pane"
}

agent_process_exists() {
	local pane="$1"
	local name="$2"
	local tty processes escaped

	[[ -z "$pane" || -z "$name" ]] && return 0

	tty="$(tmux display-message -p -t "$pane" '#{pane_tty}' 2>/dev/null || true)"
	[[ -z "$tty" ]] && return 0
	tty="${tty#/dev/}"

	processes="$(ps -t "$tty" -o comm= -o command= 2>/dev/null)" || return 0
	escaped="$(regex_escape "$name")"
	printf '%s\n' "$processes" | grep -Eiq "(^|[[:space:]/])${escaped}([[:space:]]|$)"
}

record_is_live() {
	local id="$1"
	local pane="$2"
	local name

	if ! pane_exists "$pane"; then
		return 1
	fi

	name="$(tmux_global_option "@agent_monitor_${id}_name")"
	agent_process_exists "$pane" "$name"
}

prune_instance_options() {
	local id="$1"
	local prefix="@agent_monitor_${id}"

	tmux_unset_global_option "${prefix}_name"
	tmux_unset_global_option "${prefix}_state"
	tmux_unset_global_option "${prefix}_label"
	tmux_unset_global_option "${prefix}_pane"
	tmux_unset_global_option "${prefix}_session_id"
	tmux_unset_global_option "${prefix}_updated_at"
}

refresh_status() {
	local script_dir

	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
	"${script_dir}/agent-status.sh" --refresh >/dev/null 2>&1 || true
	"${script_dir}/agent-monitor-state.sh" --refresh >/dev/null 2>&1 || true
	tmux refresh-client -S 2>/dev/null || true
}

main() {
	local instances id pane next seen

	live_pane_ids="$(live_panes)"
	instances="$(tmux_global_option @agent_monitor_instances)"
	if [[ -z "$instances" ]]; then
		return 0
	fi

	for id in $instances; do
		case " $seen " in
		*" $id "*)
			continue
			;;
		esac
		seen="${seen:+$seen }$id"

		pane="$(tmux_global_option "@agent_monitor_${id}_pane")"
		if record_is_live "$id" "$pane"; then
			next="${next:+$next }$id"
		else
			prune_instance_options "$id"
		fi
	done

	tmux_set_global_option @agent_monitor_instances "$next"
	refresh_status
}

main
exit 0
