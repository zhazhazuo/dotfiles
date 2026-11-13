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
#
# State comes from the listing daemon's file when it is fresh: one read answers
# every block, and it carries the focused pane. The API path stays for a stopped
# daemon.
#
# A finished run counts as seen when its pane is focused in the active window of
# the session the app shows. The agent keeps its state and stops asking for a
# review in the bar.

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

# ── Sources ──────────────────────────────────────────────────────────────

# The listing daemon (dotfiles/rex/scripts/listing.lua) rewrites this file after
# every Rex change and touches .alive every half minute. A fresh beat means the
# listing is current, and one read replaces a CLI process per block.
REX_LISTING="${REX_LISTING:-${XDG_CACHE_HOME:-$HOME/.cache}/rex/listing.json}"
LISTING_TTL="${REX_LISTING_TTL:-90}"

# The app records the session it displays in its preferences, and rewrites it on
# every switch. A one-line file of the same content stands in for tests.
REX_APP_PLIST="${REX_APP_PLIST:-$HOME/Library/Preferences/com.superlogical.rex.plist}"

listing_is_fresh() {
	local beat
	beat=$(cat "${REX_LISTING}.alive" 2>/dev/null || true)
	[[ -f "$REX_LISTING" && "$beat" =~ ^[0-9]+$ ]] || return 1
	[[ $(($(date +%s) - beat)) -le $LISTING_TTL ]]
}

shown_session() {
	if [[ -n "${REX_SHOWN_FILE:-}" ]]; then
		head -1 "$REX_SHOWN_FILE" 2>/dev/null | tr -d '[:space:]'
		return 0
	fi
	/usr/libexec/PlistBuddy -c "Print :'Workspace.lastFocusedSession'" \
		"$REX_APP_PLIST" 2>/dev/null |
		jq -r '.sessionID // empty' 2>/dev/null || true
}

# Is this block the focused pane of its window, according to the listing?
block_is_focused() {
	local block_id="$1"
	listing_is_fresh || return 1
	jq -e --arg b "$block_id" '
		[.sessions[]?.windows[]? | select(.active == true) | .blocks[]?
		 | select(.block_id == $b) | .focused]
		| any // false' "$REX_LISTING" >/dev/null 2>&1
}

# Mark what the user is looking at, without reconciling state. The focus events
# carry a revision and nothing else, so the listing is read.
mark_seen_from_listing() {
	local shown ids pending id keep=""
	shown=$(shown_session)
	[[ -n "$shown" ]] || return 0

	ids=$(jq -r --arg shown "$shown" '
		.sessions[]? | select(.session_id == $shown) | .windows[]?
		| select(.active == true) | .blocks[]?
		| select(.focused == true)
		| select(.state == "done" or .state == "error")
		| .block_id' "$REX_LISTING" 2>/dev/null |
		sed 's/[^[:alnum:]_]/_/g' | tr '\n' ' ')
	[[ -n "${ids// /}" ]] || return 0

	# Only agents the monitor holds as needs-attention. A done block whose
	# subagents still run is subagents-running, and stays unseen.
	pending=$("$BIN" state --json 2>/dev/null |
		jq -r '.agents | to_entries[] | select(.value.state == "needs-attention") | .key')
	for id in $ids; do
		if grep -qxF "$id" <<<"$pending"; then keep+="$id "; fi
	done
	[[ -n "$keep" ]] || return 0

	# shellcheck disable=SC2086  # sanitized ids hold no spaces
	"$BIN" seen $keep >/dev/null 2>&1 || true
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

# reconcile_block <session_id> <label> <block_id> <state> <msg> <focused>
reconcile_block() {
	local session_id="$1" label="$2" block_id="$3" state="$4" msg="${5:-}"
	local focused="${6:-false}"
	local event subs=0 title shown

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

	# A run that ended in a pane the user is looking at needs no review. A run
	# whose subagents still work is SubagentsRunning, and stays unseen.
	if [[ "$event" == "TurnComplete" && "$focused" == "true" ]]; then
		shown=$(shown_session)
		if [[ -n "$shown" && "$shown" == "$session_id" ]]; then
			"$BIN" seen "$(sanitize_id "$block_id")" >/dev/null 2>&1 || true
		fi
	fi
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

# Drop tracked rex agents that the source no longer reports.
prune_untracked() {
	local tracked="$1"
	"$BIN" state --json 2>/dev/null |
		jq -r --arg agent "$AGENT_NAME" \
			'.agents | to_entries[] | select(.value.name == $agent) | "\(.key)\t\(.value.pane // "")"' |
		while IFS=$'\t' read -r id raw_pane; do
			[[ -z "$raw_pane" ]] && continue
			grep -qxF "$raw_pane" <<<"$tracked" || "$BIN" remove "$id" >/dev/null 2>&1 || true
		done
}

do_sync() {
	if listing_is_fresh; then
		sync_from_listing
	else
		sync_from_api
	fi
}

# Reconcile every block the listing reports, and mark the ones the user is
# looking at. No rex process starts for state: only a parked block without a
# subagent count asks for its title.
sync_from_listing() {
	local session_id label block_id state msg focused tracked=""

	while IFS=$'\t' read -r session_id label block_id state msg focused; do
		[[ -z "$block_id" ]] && continue
		reconcile_block "$session_id" "$label" "$block_id" "$state" "$msg" "$focused"
		tracked+="$block_id"$'\n'
	done < <(jq -r '
		.sessions[]? as $s | $s.windows[]? as $w | $w.blocks[]?
		| select(.state != null)
		| [ $s.session_id, ($s.label // ""), .block_id, .state,
		    (.message // ""),
		    ((.focused // false) and ($w.active // false) | tostring) ]
		| @tsv' "$REX_LISTING" 2>/dev/null)

	prune_untracked "$tracked"
}

# Read state from the server one block at a time. This is the path for a stopped
# listing daemon, and it costs a rex process per session and per block.
sync_from_api() {
	local sessions session_id label view block_id window_label record
	local state msg focused block_focused tracked=""

	sessions=$(rex api call session.list 2>/dev/null) || return 0
	[[ -z "$sessions" ]] && return 0

	while IFS=$'\t' read -r session_id label; do
		[[ -z "$session_id" ]] && continue
		view=$(rex api call -s "$session_id" session.view 2>/dev/null) || continue
		[[ -z "$view" ]] && continue
		focused=$(printf '%s' "$view" | jq -r '
			.active_window_id as $a | .windows[]? | select(.window_id == $a)
			| .focused_block_id // empty' | tr '\n' ' ')

		while IFS=$'\t' read -r block_id _ window_label; do
			[[ -z "$block_id" ]] && continue
			record=$(block_status "$session_id" "$block_id")
			if [[ -z "$record" ]]; then
				remove_block "$block_id"
				continue
			fi
			state=$(printf '%s' "$record" | jq -r '.state // empty')
			msg=$(printf '%s' "$record" | jq -r '.msg // empty')
			block_focused=false
			case " $focused " in
			*" $block_id "*) block_focused=true ;;
			esac
			reconcile_block "$session_id" "${label:-$window_label}" "$block_id" "$state" "$msg" "$block_focused"
			tracked+="$block_id"$'\n'
		done < <(printf '%s' "$view" | jq -r '
			.windows[]? as $w | $w.layers[]?.blocks[]? |
			[.block_id, (.label // ""), ($w.label // "")] | @tsv')
	done < <(printf '%s' "$sessions" | jq -r '.sessions[]? | [.session_id, (.label // "")] | @tsv')

	prune_untracked "$tracked"
}

# Handle one line of `rex events --all --json`.
handle_event() {
	local line="$1" session_id block_id name state msg label record focused=false

	name=$(printf '%s' "$line" | jq -r '
		.payload.event.payload.name // .payload.event.type // empty' 2>/dev/null) || return 0
	[[ -z "$name" ]] && return 0

	session_id=$(printf '%s' "$line" | jq -r '.payload.session_id // empty' 2>/dev/null) || return 0

	case "$name" in
	session_view_changed | active_window_changed)
		# Focus moved: the user switched a tab or picked a pane. The event
		# carries a revision and nothing else, so the listing answers.
		if listing_is_fresh; then
			mark_seen_from_listing
		else
			sync_from_api
		fi
		return 0
		;;
	esac

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
		if block_is_focused "$block_id"; then focused=true; fi
		reconcile_block "$session_id" "$label" "$block_id" "$state" "$msg" "$focused"
		;;
	program_status_changed)
		state=$(printf '%s' "$line" | jq -r '.payload.event.payload.payload.record.state // empty')
		msg=$(printf '%s' "$line" | jq -r '.payload.event.payload.payload.record.msg // empty')
		label=$(session_label "$session_id")
		if block_is_focused "$block_id"; then focused=true; fi
		reconcile_block "$session_id" "$label" "$block_id" "$state" "$msg" "$focused"
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
