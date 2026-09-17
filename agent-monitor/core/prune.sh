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

# ── Stale Subagent Demotion ──────────────────────────────────────────────

# pi-subagents refreshes its pane labels every 45s while subagents run, and
# herdr expires them on its own TTL. A parked main agent whose heartbeat stopped
# is therefore abandoned (parent died, labels never cleared): demote it to
# needs-attention so the indicator does not claim work that is not happening.
# No notification — only the agent-side transition into needs-attention notifies.
SUBAGENT_STALE_SECONDS="${AGENT_MONITOR_SUBAGENT_STALE_SECONDS:-150}"

demote_abandoned_subagents() {
	local now id state checked age
	now=$(date +%s)

	for id in $(list_agents); do
		state=$(get_field "$id" "state")
		[[ "$state" == "subagents-running" ]] || continue

		checked=$(get_field "$id" "subagents_checked_at")
		[[ "$checked" =~ ^[0-9]+$ ]] || checked=0

		age=$((now - checked))
		if [[ "$age" -gt "$SUBAGENT_STALE_SECONDS" ]]; then
			demote_subagents "$id"
			printf '%s\n' "$id"
		fi
	done
}

# Main prune logic
prune() {
	local live_pane_ids
	live_pane_ids=$(live_panes)

	local ids_to_remove=()
	local subagents_demoted

	# Abandoned parked agents first: herdr entries are skipped by the liveness
	# sweep below, so this is their only cleanup path in here.
	subagents_demoted=$(demote_abandoned_subagents)

	for id in $(list_agents); do
		local pane name

		pane=$(get_field "$id" "pane")
		name=$(get_field "$id" "name")

		# Herdr agents use herdr pane ids, not tmux panes. Their lifecycle
		# is handled by pane.closed events and adapters/herdr.sh --sync.
		[[ "$name" == "herdr" ]] && continue

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
	fi

	# Refresh sinks after any state change
	if [[ ${#ids_to_remove[@]} -gt 0 || -n "$subagents_demoted" ]]; then
		refresh_sinks
	fi
}

# Remove a specific agent by ID (used by adapters on session end)
remove_by_id() {
	local id="$1"

	if [[ -n "$(get_agent "$id")" ]]; then
		remove_agent "$id"
		refresh_sinks
	fi
}
