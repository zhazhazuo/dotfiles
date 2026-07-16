#!/usr/bin/env bash
#
# agent-monitor/sinks/sketchybar.sh — SketchyBar plugin
#
# Reads agent-monitor state.json and renders SketchyBar items.
# Triggered by agent_monitor_update events.
#
# Install: symlink or copy to ~/.config/sketchybar/plugins/agent_monitor.sh

set -euo pipefail

# Resolve symlink to find actual script location
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
	DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
	SOURCE="$(readlink "$SOURCE")"
	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SINK_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
CORE_DIR="${SINK_DIR}/../core"
source "${CORE_DIR}/state.sh"

# ── Configuration ────────────────────────────────────────────────────────

ATTENTION_TIMEOUT=$(tmux show-options -gqv @agent_monitor_attention_timeout 2>/dev/null || echo 300)

# ── State → Color ────────────────────────────────────────────────────────

color_for_state() {
	case "$1" in
	needs-help) printf '0xffc0392b' ;;
	needs-attention) printf '0xff1f6feb' ;;
	running) printf '0xff238636' ;;
	*) printf '0xffaaaaaa' ;;
	esac
}

# ── Timeout Decay ────────────────────────────────────────────────────────

effective_state() {
	local state="$1" updated_at="$2" now="$3"
	if [[ "$state" == "needs-attention" ]] && [[ "$updated_at" =~ ^[0-9]+$ ]]; then
		if [[ "$((now - updated_at))" -gt "$ATTENTION_TIMEOUT" ]]; then
			printf 'idle'
			return 0
		fi
	fi
	printf '%s' "$state"
}

# ── Priority for sorting ─────────────────────────────────────────────────

priority_for_state() {
	case "$1" in
	needs-help) printf '4' ;;
	needs-attention) printf '3' ;;
	running) printf '2' ;;
	idle) printf '1' ;;
	*) printf '0' ;;
	esac
}

# ── SketchyBar Item Management ──────────────────────────────────────────

sanitize_item_id() {
	printf '%s' "$1" | tr -c '[:alnum:]_' '_'
}

item_exists() {
	sketchybar --query "$1" >/dev/null 2>&1
}

ensure_item() {
	local item="$1"
	item_exists "$item" || sketchybar --add item "$item" center
}

set_item_style() {
	local item="$1" state="$2" label="$3" pane="$4"
	local color click_script

	color="$(color_for_state "$state")"

	if [[ -n "$pane" ]]; then
		click_script="tmux select-window -t $pane; tmux select-pane -t $pane"
	else
		click_script=""
	fi

	sketchybar --set "$item" \
		drawing=on \
		icon.drawing=off \
		label="<$label>" \
		label.color="$color" \
		background.drawing=off \
		click_script="$click_script"
}

# ── Cache (track which items we created) ────────────────────────────────

cache_file() {
	printf '%s/sketchybar-agent-monitor-items.%s' "${TMPDIR:-/tmp}" "${UID:-$(id -u)}"
}

contains_id() {
	local needle="$1" item
	for item in $current_ids; do
		[[ "$item" == "$needle" ]] && return 0
	done
	return 1
}

remove_stale_items() {
	local cache="$1" previous id
	[[ -r "$cache" ]] && previous="$(cat "$cache")"
	for id in $previous; do
		if ! contains_id "$id"; then
			sketchybar --remove "agent_monitor.${id}" >/dev/null 2>&1 || true
		fi
	done
}

# ── Main Render ──────────────────────────────────────────────────────────

render() {
	local cache now current_ids=""
	local ids_to_render=()

	cache="$(cache_file)"
	now=$(date +%s)

	# Collect agents sorted by priority (highest first)
	while IFS=$'\t' read -r priority id state label pane updated_at; do
		[[ -z "$id" ]] && continue

		local effective
		effective=$(effective_state "$state" "$updated_at" "$now")
		id=$(sanitize_item_id "$id")
		ids_to_render+=("${priority}|${id}|${effective}|${label}|${pane}")
		current_ids="${current_ids:+$current_ids }$id"
	done < <(
		for id in $(list_agents); do
			local state label pane updated_at priority effective
			state=$(get_field "$id" "state")
			label=$(get_field "$id" "label")
			pane=$(get_field "$id" "pane")
			updated_at=$(get_field "$id" "updated_at")
			effective=$(effective_state "$state" "$updated_at" "$now")
			priority=$(priority_for_state "$effective")
			printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$priority" "$id" "$state" "$label" "$pane" "$updated_at"
		done | sort -t$'\t' -k1,1nr -k2,2
	)

	# Remove stale items
	remove_stale_items "$cache"

	# Hide parent item if no agents
	if [[ ${#ids_to_render[@]} -eq 0 ]]; then
		sketchybar --set agent_monitor drawing=off 2>/dev/null || true
		printf '' >"$cache"
		return 0
	fi

	# Hide parent item (we use child items)
	sketchybar --set agent_monitor drawing=off 2>/dev/null || true

	# Render each agent as a child item
	for entry in "${ids_to_render[@]}"; do
		IFS='|' read -r _ id effective label pane <<<"$entry"
		local item="agent_monitor.${id}"
		ensure_item "$item"
		set_item_style "$item" "$effective" "${label:-agent}" "$pane"
	done

	# Write cache
	mkdir -p "$(dirname "$cache")"
	printf '%s\n' "$current_ids" >"$cache"
}

# ── Entry Point ──────────────────────────────────────────────────────────

case "${SENDER:-}" in
mouse.clicked)
	# Focus the highest-priority agent's pane
	record="$(
		{
			for id in $(list_agents); do
				state=$(get_field "$id" "state")
				pane=$(get_field "$id" "pane")
				priority=$(priority_for_state "$(effective_state "$state" "$(get_field "$id" "updated_at")" "$(date +%s)")")
				printf '%s\t%s\t%s\n' "$priority" "$id" "$pane"
			done
		} | sort -t$'\t' -k1,1nr | head -1
	)"
	if [[ -n "$record" ]]; then
		pane=$(printf '%s' "$record" | cut -f3)
		[[ -n "$pane" ]] && tmux select-window -t "$pane" 2>/dev/null && tmux select-pane -t "$pane" 2>/dev/null
	fi
	;;
*)
	render
	;;
esac
