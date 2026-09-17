#!/usr/bin/env bash
#
# agent-monitor/adapters/herdr.sh — Herdr source adapter
#
# Called by herdr-plugin/on-event.sh with a herdr event name, or with
# --sync for a full reconcile from the herdr snapshot.
#
# Herdr agent_status → generic event mapping:
#   working → RunStart        blocked → PermissionRequest
#   done    → TurnComplete    idle    → SessionStart
#   unknown / missing → remove (agent gone or not an agent pane)

set -euo pipefail

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${ADAPTER_DIR}/../bin/agent-monitor"

command -v herdr >/dev/null 2>&1 || exit 0

sanitize_id() {
	printf '%s' "$1" | tr -c '[:alnum:]_' '_'
}

map_status() {
	case "$1" in
	working) printf 'RunStart' ;;
	blocked) printf 'PermissionRequest' ;;
	done) printf 'TurnComplete' ;;
	idle) printf 'SessionStart' ;;
	*) return 1 ;;
	esac
}

snapshot() {
	local output
	output=$(herdr api snapshot 2>/dev/null) || true
	if [[ -z "$output" ]] || ! printf '%s' "$output" | jq -e . >/dev/null 2>&1; then
		return 0
	fi
	printf '%s' "$output"
}

remove_pane() {
	"$BIN" remove "$(sanitize_id "$1")" >/dev/null 2>&1 || true
}

# ── Subagent Detection ───────────────────────────────────────────────────

# pi-subagents owns pane display metadata while background subagents run:
#   --state-label idle=done=working="⏳ N subagent(s) (names)" --token summary=...
# The label that applies is the pane's current status; the summary token is a
# fallback for a report that arrived without labels. Matched case-insensitively
# on "subagent" so a label of another reporter cannot be read as one.
subagent_count() {
	local entry="$1" status="$2" text

	text=$(printf '%s' "$entry" | jq -r --arg st "$status" '
		[ (.state_labels // {})[$st],
		  ((.state_labels // {}) | to_entries[]? | .value),
		  (.tokens.summary // empty) ]
		| map(select(type == "string") | select(test("subagent"; "i")))
		| first // empty' 2>/dev/null || true)

	if [[ -z "$text" ]]; then
		printf '0'
		return 0
	fi

	if [[ "$text" =~ ([0-9]+)[[:space:]]+[Ss]ubagents? ]]; then
		printf '%s' "${BASH_REMATCH[1]}"
		return 0
	fi

	printf '1'
}

# Reconcile one herdr pane from a snapshot.
# Usage: reconcile_pane <snapshot_json> <pane_id>
reconcile_pane() {
	local snap="$1" pane_id="$2"
	local entry status event tab_id label cwd count=0

	entry=$(printf '%s' "$snap" | jq -c --arg pid "$pane_id" \
		'first(.result.snapshot.agents[]? | select(.pane_id == $pid)) // empty')

	if [[ -z "$entry" ]]; then
		# Pane has no agent (anymore) — drop any tracked entry.
		remove_pane "$pane_id"
		return 0
	fi

	status=$(printf '%s' "$entry" | jq -r '.agent_status // "unknown"')
	if ! event=$(map_status "$status"); then
		remove_pane "$pane_id"
		return 0
	fi

	# Main agent parked with background subagents still running: report the
	# distinct state so the indicator is not read as "finished, review me".
	# blocked/working keep their own state — those are the urgent/active ones.
	if [[ "$status" == "done" || "$status" == "idle" ]]; then
		count=$(subagent_count "$entry" "$status")
		if [[ "$count" -gt 0 ]]; then
			event="SubagentsRunning"
		fi
	fi

	tab_id=$(printf '%s' "$entry" | jq -r '.tab_id // empty')
	label=$(printf '%s' "$snap" | jq -r --arg tid "$tab_id" \
		'first(.result.snapshot.tabs[]? | select(.tab_id == $tid) | .label) // empty' 2>/dev/null || true)
	cwd=$(printf '%s' "$entry" | jq -r '.cwd // empty')

	"$BIN" reconcile herdr "$event" "$(jq -nc \
		--arg pid "$pane_id" --arg label "$label" --arg cwd "$cwd" --argjson subs "$count" \
		'{pane_id: $pid, label: $label, cwd: $cwd, subagents: $subs}')"
}

event_pane_id() {
	local pane_id="${HERDR_PANE_ID:-}"
	if [[ -z "$pane_id" ]]; then
		pane_id=$(printf '%s' "${HERDR_PLUGIN_EVENT_JSON:-{\}}" |
			jq -r '.pane_id // empty' 2>/dev/null || true)
	fi
	printf '%s' "$pane_id"
}

do_event() {
	local event="$1" pane_id snap

	pane_id=$(event_pane_id)
	[[ -z "$pane_id" ]] && exit 0

	case "$event" in
	pane.closed)
		remove_pane "$pane_id"
		;;
	pane.agent_status_changed | pane.agent_detected)
		snap=$(snapshot)
		[[ -z "$snap" ]] && exit 0
		reconcile_pane "$snap" "$pane_id"
		;;
	esac
}

do_sync() {
	local snap pid id raw_pane known tracked

	snap=$(snapshot)
	[[ -z "$snap" ]] && exit 0

	# Reconcile every current agent
	for pid in $(printf '%s' "$snap" | jq -r '.result.snapshot.agents[]?.pane_id'); do
		reconcile_pane "$snap" "$pid"
	done

	# Remove tracked herdr agents that are gone or no longer agents
	tracked=$("$BIN" state --json | jq -r \
		'.agents | to_entries[] | select(.value.name == "herdr") | "\(.key)\t\(.value.pane // "")"')
	while IFS=$'\t' read -r id raw_pane; do
		[[ -z "$id" ]] && continue
		known=$(printf '%s' "$snap" | jq -r --arg pid "$raw_pane" \
			'[.result.snapshot.agents[]? | select(.pane_id == $pid and .agent_status != "unknown")] | length')
		if [[ "$known" == "0" ]]; then
			"$BIN" remove "$id" >/dev/null 2>&1 || true
		fi
	done <<<"$tracked"
}

case "${1:---sync}" in
--sync | startup)
	do_sync
	;;
*)
	do_event "$1"
	;;
esac
