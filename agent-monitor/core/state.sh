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
print_tsv() {
	printf 'id\tname\tstate\tlabel\tpane\tsession_id\tupdated_at\n'
	read_state | jq -r '
		.agents
		| to_entries[]
		| [
			.key,
			.value.name // "",
			.value.state // "",
			.value.label // "",
			.value.pane // "",
			.value.session_id // "",
			(.value.updated_at // 0 | tostring)
		]
		| @tsv
	' 2>/dev/null || true
}

# ── Mutation Operations ──────────────────────────────────────────────────

# Upsert an agent record. Takes fields as key=value pairs.
# Usage: upsert_agent "%4" name=pi state=running label=REPO-WIKI pane="%4"
upsert_agent() {
	local id="$1"
	shift

	# Build the update JSON from key=value pairs
	local update='{}'
	for kv in "$@"; do
		local key="${kv%%=*}"
		local value="${kv#*=}"
		update=$(printf '%s' "$update" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
	done

	# Add updated_at
	update=$(printf '%s' "$update" | jq --arg ts "$(date +%s)" '. + {updated_at: ($ts | tonumber)}')

	# Merge into state
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
		'{state: $state, updated_at: ($ts | tonumber)}')

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
