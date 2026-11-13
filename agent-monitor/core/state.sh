#!/usr/bin/env bash
#
# agent-monitor/core/state.sh — JSON state store read/write
#
# Manages ~/.cache/agent-monitor/state.json
# All mutations go through this module to ensure consistency.

set -euo pipefail

STATE_DIR="${AGENT_MONITOR_STATE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/agent-monitor}"
STATE_FILE="${STATE_FILE:-${STATE_DIR}/state.json}"

# ── Helpers ──────────────────────────────────────────────────────────────

ensure_state_dir() {
	mkdir -p "$STATE_DIR"
}

state_file() {
	printf '%s' "$STATE_FILE"
}

# Read the full state JSON. Returns empty valid JSON if file doesn't exist.
read_state() {
	if [[ -f "$STATE_FILE" ]]; then
		cat "$STATE_FILE"
	else
		printf '{"version":1,"agents":{}}\n'
	fi
}

# Write state atomically (tmp + mv).
write_state() {
	ensure_state_dir
	local tmp="${STATE_FILE}.$$"
	cat >"$tmp"
	mv "$tmp" "$STATE_FILE"
}

# ── Query Operations ─────────────────────────────────────────────────────

# List all agent IDs (pane IDs)
list_agents() {
	read_state | jq -r '.agents | keys[]' 2>/dev/null || true
}

# Get a single agent's full record as JSON
get_agent() {
	local id="$1"
	read_state | jq --arg id "$id" '.agents[$id] // empty' 2>/dev/null
}

# Get a single field from an agent
get_field() {
	local id="$1" field="$2"
	read_state | jq -r --arg id "$id" --arg field "$field" \
		'.agents[$id][$field] // empty' 2>/dev/null
}

# Print state as TSV (for legacy consumers like SketchyBar)
# Print state as TSV (for legacy consumers like SketchyBar). A field that is
# empty prints as "-": the sink reads the row positionally, and empty fields
# would collapse under tab splitting and shift every later column.
print_tsv() {
	printf 'id\tname\tstate\tlabel\tpane\tsession_id\tupdated_at\tseen\n'
	read_state | jq -r '
		def filled: if . == null or . == "" then "-" else . end;
		.agents
		| to_entries[]
		| [
			.key,
			.value.name // "",
			.value.state // "",
			.value.label // "",
			(.value.pane | filled),
			(.value.session_id | filled),
			(.value.updated_at // 0 | tostring),
			(.value.seen // 0 | tostring)
		]
		| @tsv
	' 2>/dev/null || true
}

# Mark agents as seen: the user has looked at the finished result, so the
# indicator stops asking for a review. Returns 1 when nothing changed.
# Usage: mark_seen <id>...
mark_seen() {
	[[ "$#" -gt 0 ]] || return 1

	local before after
	before=$(read_state)
	after=$(printf '%s' "$before" | jq --args '
		(.agents | keys) as $known
		| [$ARGS.positional[] | select(. as $id | $known | index($id))] as $targets
		| reduce $targets[] as $id (.; .agents[$id].seen = 1)
	' "$@")

	[[ "$after" == "$before" ]] && return 1
	printf '%s' "$after" | write_state
	return 0
}

# Clear a seen mark, so the next result asks again.
clear_seen() {
	local id="$1"
	read_state | jq --arg id "$id" \
		'.agents[$id] = ((.agents[$id] // {}) * {seen: 0})' | write_state
}

# ── Mutation Operations ──────────────────────────────────────────────────

# Upsert an agent record. Takes fields as key=value pairs.
# Usage: upsert_agent "%4" name=pi state=running label=REPO-WIKI pane="%4"
upsert_agent() {
	local id="$1"
	shift

	# One jq builds the update and one merges it. A process per field was the
	# slowest step in a state change.
	local update
	update=$(jq -n --arg ts "$(date +%s)" --args '
		$ARGS.positional
		| map(split("=") | {(.[0]): (.[1:] | join("="))})
		| add + {updated_at: ($ts | tonumber)}' "$@")

	read_state | jq --arg id "$id" --argjson update "$update" \
		'.agents[$id] = ((.agents[$id] // {}) * $update)' | write_state
}

# Remove an agent
remove_agent() {
	local id="$1"
	read_state | jq --arg id "$id" 'del(.agents[$id])' | write_state
}

# Remove multiple agents
remove_agents() {
	local ids=("$@")
	local jq_filter='.agents'
	for id in "${ids[@]}"; do
		jq_filter="$jq_filter | del(.[\"$id\"])"
	done
	read_state | jq "$jq_filter" | write_state
}

# Clear all state
clear_state() {
	printf '{"version":1,"agents":{}}\n' | write_state
}

# ── Transition Helpers ───────────────────────────────────────────────────

# Record a state transition. Returns previous state for notification logic.
transition_agent() {
	local id="$1" new_state="$2"
	local prev_state

	prev_state=$(get_field "$id" "state")

	if [[ "$prev_state" == "$new_state" ]]; then
		# No change, skip write
		printf '%s' "$prev_state"
		return 0
	fi

	# Build update with state change
	local now
	now=$(date +%s)
	local update
	update=$(jq -n --arg state "$new_state" --arg ts "$now" \
		'{state: $state, updated_at: ($ts | tonumber), seen: 0}')

	# Add turn_completed_at for attention states
	case "$new_state" in
	needs-attention | needs-help)
		update=$(printf '%s' "$update" | jq --arg ts "$now" \
			'. + {turn_completed_at: ($ts | tonumber)}')
		;;
	esac

	# Merge into state
	read_state | jq --arg id "$id" --argjson update "$update" \
		'.agents[$id] = ((.agents[$id] // {}) * $update)' | write_state

	printf '%s' "$prev_state"
}

# ── Subagent Heartbeat ───────────────────────────────────────────────────

# Record the subagent heartbeat for a parked main agent.
# Deliberately does not bump updated_at: that field tracks real state changes
# and the sinks sort on it, so a 45s refresh must not reshuffle the status bar.
touch_subagents() {
	local id="$1" count="${2:-0}" now
	[[ "$count" =~ ^[0-9]+$ ]] || count=0
	now=$(date +%s)

	read_state | jq --arg id "$id" --argjson n "$count" --arg ts "$now" \
		'.agents[$id] = ((.agents[$id] // {}) * {subagents_count: $n, subagents_checked_at: ($ts | tonumber)})' \
		| write_state
}

# Demote a parked main agent to needs-attention. Used when its subagent
# heartbeat went stale: the parent died without clearing its pane labels.
demote_subagents() {
	local id="$1"

	read_state | jq --arg id "$id" \
		'.agents[$id] = ((.agents[$id] // {}) * {state: "needs-attention", subagents_count: 0, seen: 0})' \
		| write_state
}

# Clear the subagent bookkeeping once the main agent is no longer parked.
clear_subagents() {
	local id="$1"

	read_state | jq --arg id "$id" \
		'.agents[$id] = ((.agents[$id] // {}) * {subagents_count: 0, subagents_checked_at: null})' \
		| write_state
}

# ── Sink Refresh ─────────────────────────────────────────────────────────

# Refresh all sinks after a state change. Single definition, used by
# reconcile.sh, prune.sh, and bin/agent-monitor.
refresh_sinks() {
	local core_dir sinks_dir tsv_tmp
	core_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	sinks_dir="${core_dir}/../sinks"

	# Export TSV for the SketchyBar sink (atomic write)
	ensure_state_dir
	tsv_tmp="${STATE_DIR}/state.tsv.$$"
	print_tsv >"$tsv_tmp"
	mv "$tsv_tmp" "${STATE_DIR}/state.tsv"

	if command -v sketchybar >/dev/null 2>&1; then
		(sketchybar --trigger agent_monitor_update 2>/dev/null || true) &
	fi
}
