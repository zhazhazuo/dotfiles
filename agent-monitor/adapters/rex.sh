#!/usr/bin/env bash
#
# agent-monitor/adapters/rex.sh — Rex source adapter
#
# Rex publishes per-block program status itself, over OSC 7501, and streams it
# as a server event. This adapter therefore needs no plugin: it either reads the
# current view, or follows the event stream.
#
# Usage:
#   rex.sh --sync      reconcile every block that reports a status
#   rex.sh --watch     sync once, then follow `rex events --all --json`
#
# Rex program status → generic event:
#   working → RunStart            blocked → PermissionRequest
#   done    → TurnComplete        idle    → SessionStart
#   error   → TurnComplete        (the run ended; it still needs review)
#   no record, program_status_removed, block_closed → remove
#
# A parked agent whose message carries a subagent count, or whose title does, becomes
# SubagentsRunning, matching the herdr adapter's contract. pi never puts the count
# in its status message, so in practice the title carries it.
#
# Identity is the block id, sanitized (block:01a1… → block_01a1…), with the raw
# id kept in the state's pane field so a click can focus it.

set -euo pipefail

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${ADAPTER_DIR}/../bin/agent-monitor"
AGENT_NAME="rex"

# Rex sends its own macOS notifications when a program it runs reports a
# status. This bridge must not send a second one, and an osascript
# notification would be attributed to Script Editor anyway.
export AGENT_MONITOR_NOTIFY="${AGENT_MONITOR_NOTIFY:-off}"

command -v rex >/dev/null 2>&1 || exit 0

sanitize_id() {
	printf '%s' "$1" | tr -c '[:alnum:]_' '_'
}

map_state() {
	case "$1" in
	working) printf 'RunStart' ;;
	blocked) printf 'PermissionRequest' ;;
	done) printf 'TurnComplete' ;;
	idle) printf 'SessionStart' ;;
	error) printf 'TurnComplete' ;;
	*) return 1 ;;
	esac
}

# A message such as "3 subagents (a, b, c)" means background work continues.
subagent_count() {
	local text="${1:-}"
	if [[ "$text" =~ ([0-9]+)[[:space:]]+[Ss]ubagents? ]]; then
		printf '%s' "${BASH_REMATCH[1]}"
		return 0
	fi
	printf '0'
}

# Read a block's terminal title, which a program sets with OSC 2. Rex has no pane
# metadata channel, so pi's extension rex-subagents-running publishes the count
# here; pi's own program status message carries only the session name.
block_title() {
	local session_id="$1" block_id="$2"
	rex api call -s "$session_id" com.superlogical.terminal.title \
		"$(jq -nc --arg b "$block_id" '{block_id: $b}')" 2>/dev/null |
		jq -r '.title // empty' 2>/dev/null || true
}

remove_block() {
	"$BIN" remove "$(sanitize_id "$1")" >/dev/null 2>&1 || true
}

# Resolve a session's display label. Called once per event, the way the herdr
# adapter reads a whole snapshot per event.
session_label() {
	rex ls --json 2>/dev/null |
		jq -r --arg sid "$1" 'first(.sessions[]? | select(.session_id == $sid) | .label) // empty' \
			2>/dev/null || true
}

# reconcile_block <session_id> <label> <block_id> <state> <msg> [title]
reconcile_block() {
	local session_id="$1" label="$2" block_id="$3" state="$4" msg="${5:-}" title="${6:-}"
	local event subs=0

	event=$(map_state "$state") || {
		remove_block "$block_id"
		return 0
	}

	if [[ "$state" == "done" || "$state" == "idle" ]]; then
		subs=$(subagent_count "$msg")
		if [[ "$subs" -eq 0 ]]; then
			[[ -n "$title" ]] || title=$(block_title "$session_id" "$block_id")
			subs=$(subagent_count "$title")
		fi
		if [[ "$subs" -gt 0 ]]; then
			event="SubagentsRunning"
		fi
	fi

	"$BIN" reconcile "$AGENT_NAME" "$event" "$(jq -nc \
		--arg pane_id "$block_id" --arg label "$label" --arg sid "$session_id" \
		--arg msg "$msg" --argjson subs "$subs" \
		'{pane_id: $pane_id, label: $label, session_id: $sid, message: $msg, subagents: $subs}')"
}

# Read the strongest status record for one block.
# The root record carries no id; child records are named like `build/test`.
block_status() {
	local session_id="$1" block_id="$2"
	rex api call -s "$session_id" com.superlogical.terminal.program_status \
		"$(jq -nc --arg b "$block_id" '{block_id: $b}')" 2>/dev/null |
		jq -c 'first(.records[]? | select(.id == "")) // first(.records[]?) // empty' \
			2>/dev/null || true
}

do_sync() {
	local sessions session_id label view block_id block_label window_label record
	local state msg seen=""

	sessions=$(rex api call session.list 2>/dev/null) || exit 0
	[[ -z "$sessions" ]] && exit 0

	while IFS=$'\t' read -r session_id label; do
		[[ -z "$session_id" ]] && continue
		view=$(rex api call -s "$session_id" session.view 2>/dev/null) || continue
		[[ -z "$view" ]] && continue

		while IFS=$'\t' read -r block_id block_label window_label; do
			[[ -z "$block_id" ]] && continue
			record=$(block_status "$session_id" "$block_id")
			if [[ -z "$record" ]]; then
				remove_block "$block_id"
				continue
			fi
			state=$(printf '%s' "$record" | jq -r '.state // empty')
			msg=$(printf '%s' "$record" | jq -r '.msg // empty')
			reconcile_block "$session_id" "${label:-$window_label}" "$block_id" "$state" "$msg"
			seen+="$block_id"$'\n'
		done < <(printf '%s' "$view" | jq -r '
			.windows[]? as $w | $w.layers[]?.blocks[]? |
			[.block_id, (.label // ""), ($w.label // "")] | @tsv')
	done < <(printf '%s' "$sessions" | jq -r '.sessions[]? | [.session_id, (.label // "")] | @tsv')

	# Drop tracked rex agents that no longer report status.
	"$BIN" state --json 2>/dev/null |
		jq -r --arg agent "$AGENT_NAME" \
			'.agents | to_entries[] | select(.value.name == $agent) | "\(.key)\t\(.value.pane // "")"' |
		while IFS=$'\t' read -r id raw_pane; do
			[[ -z "$raw_pane" ]] && continue
			grep -qxF "$raw_pane" <<<"$seen" || "$BIN" remove "$id" >/dev/null 2>&1 || true
		done
}

# Handle one line of `rex events --all --json`.
handle_event() {
	local line="$1" session_id block_id name state msg label record

	name=$(printf '%s' "$line" | jq -r '
		.payload.event.payload.name // .payload.event.type // empty' 2>/dev/null) || return 0
	[[ -z "$name" ]] && return 0

	session_id=$(printf '%s' "$line" | jq -r '.payload.session_id // empty' 2>/dev/null) || return 0
	block_id=$(printf '%s' "$line" | jq -r '
		.payload.event.payload.block_id // empty' 2>/dev/null) || return 0
	[[ -z "$block_id" ]] && return 0

	case "$name" in
	title_changed)
		# The subagent bridge rewrites the title while threads run, clock tick
		# included, so every change re-arms the monitor's heartbeat.
		record=$(block_status "$session_id" "$block_id")
		[[ -z "$record" ]] && return 0
		state=$(printf '%s' "$record" | jq -r '.state // empty')
		[[ -z "$state" ]] && return 0
		msg=$(printf '%s' "$record" | jq -r '.msg // empty')
		label=$(session_label "$session_id")
		reconcile_block "$session_id" "$label" "$block_id" "$state" "$msg"
		;;
	program_status_changed)
		state=$(printf '%s' "$line" | jq -r '.payload.event.payload.payload.record.state // empty')
		msg=$(printf '%s' "$line" | jq -r '.payload.event.payload.payload.record.msg // empty')
		label=$(session_label "$session_id")
		reconcile_block "$session_id" "$label" "$block_id" "$state" "$msg"
		;;
	program_status_removed | block_closed)
		remove_block "$block_id"
		;;
	esac
	return 0
}

do_watch() {
	do_sync
	rex events --all --json 2>/dev/null | while IFS= read -r line; do
		handle_event "$line" || true
	done
}

case "${1:---sync}" in
--sync | sync)
	do_sync
	;;
--watch | watch)
	do_watch
	;;
*)
	printf 'usage: %s [--sync|--watch]\n' "$0" >&2
	exit 2
	;;
esac
