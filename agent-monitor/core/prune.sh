#!/usr/bin/env bash
#
# agent-monitor/core/prune.sh — Remove dead agents from state
#
# Checks each tracked agent:
#   - Does the pane still exist?
#   - Is the agent process still running on that pane's TTY?
#
# Dead entries are removed. Called by tmux pane-exited/after-kill-pane hooks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/state.sh"

# Get all live tmux pane IDs
live_panes() {
	tmux list-panes -a -F '#{pane_id}' 2>/dev/null || true
}

# Check if an agent process is running on a pane's TTY
agent_process_exists() {
	local pane="$1" name="$2"
	local tty processes

	[[ -z "$pane" || -z "$name" ]] && return 0

	tty=$(tmux display-message -p -t "$pane" '#{pane_tty}' 2>/dev/null || true)
	[[ -z "$tty" ]] && return 0
	tty="${tty#/dev/}"

	processes=$(ps -t "$tty" -o comm= -o command= 2>/dev/null) || return 0

	case "$name" in
	cursor)
		printf '%s\n' "$processes" | grep -Eiq 'cursor-agent/versions/|\.local/bin/agent'
		return $?
		;;
	esac

	printf '%s\n' "$processes" | grep -Eiq "(^|[[:space:]/])${name}([[:space:]]|$)"
}

# Main prune logic
prune() {
	local live_pane_ids
	live_pane_ids=$(live_panes)

	local ids_to_remove=()

	for id in $(list_agents); do
		local pane name

		pane=$(get_field "$id" "pane")
		name=$(get_field "$id" "name")

		# Skip agents without pane metadata (explicit logical IDs)
		[[ -z "$pane" ]] && continue

		# Check if pane exists
		if ! printf '%s\n' "$live_pane_ids" | grep -Fxq "$pane"; then
			ids_to_remove+=("$id")
			continue
		fi

		# Check if agent process is still running
		if ! agent_process_exists "$pane" "$name"; then
			ids_to_remove+=("$id")
			continue
		fi
	done

	# Remove dead entries
	if [[ ${#ids_to_remove[@]} -gt 0 ]]; then
		for id in "${ids_to_remove[@]}"; do
			remove_agent "$id"
		done

		# Refresh sinks after pruning
		refresh_sinks
	fi
}

# Also export for use by reconcile.sh
refresh_sinks() {
	local sinks_dir="${SCRIPT_DIR}/../sinks"

	if [[ -x "${sinks_dir}/tmux-status.sh" ]]; then
		"${sinks_dir}/tmux-status.sh" --refresh 2>/dev/null || true
	fi

	if command -v sketchybar >/dev/null 2>&1; then
		(sketchybar --trigger agent_monitor_update 2>/dev/null || true) &
	fi

	tmux refresh-client -S 2>/dev/null || true
}
