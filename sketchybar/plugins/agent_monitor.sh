#!/usr/bin/env bash

set -euo pipefail

state_file() {
	if [[ -n "${AGENT_MONITOR_STATE_FILE:-}" ]]; then
		printf '%s' "$AGENT_MONITOR_STATE_FILE"
		return 0
	fi

	printf '%s/agent-monitor/agent-monitor.%s.tsv' "${XDG_CACHE_HOME:-${HOME}/.cache}" "${UID:-$(id -u)}"
}

priority_for_state() {
	case "$1" in
	needs-help) printf '4' ;;
	needs-attention) printf '3' ;;
	running) printf '2' ;;
	idle) printf '1' ;;
	*) printf '0' ;;
	esac
}

cache_file() {
	if [[ -n "${AGENT_MONITOR_SKETCHYBAR_CACHE:-}" ]]; then
		printf '%s' "$AGENT_MONITOR_SKETCHYBAR_CACHE"
		return 0
	fi

	printf '%s/sketchybar-agent-monitor-items.%s' "${TMPDIR:-/tmp}" "${UID:-$(id -u)}"
}

sanitize_item_id() {
	printf '%s' "$1" | tr -c '[:alnum:]_' '_'
}

color_for_state() {
	case "$1" in
	needs-help) printf '0xffc0392b' ;;
	needs-attention) printf '0xff1f6feb' ;;
	running) printf '0xff238636' ;;
	*) printf '0xffaaaaaa' ;;
	esac
}

set_item_style() {
	local item="$1"
	local state="$2"
	local label="$3"
	local pane="$4"
	local click_script color

	color="$(color_for_state "$state")"
	click_script="$(click_script_for_pane "$pane")"

	if [[ "$state" == "idle" ]]; then
		sketchybar --set "$item" \
			drawing=on \
			icon.drawing=off \
			label="$label" \
			label.color="$color" \
			background.drawing=off \
			background.color=0x00000000 \
			background.corner_radius=5 \
			background.height=20 \
			click_script="$click_script"
		return 0
	fi

	sketchybar --set "$item" \
		drawing=on \
		icon.drawing=off \
		label="$label" \
		label.color=0xffffffff \
		background.drawing=on \
		background.color="$color" \
		background.corner_radius=5 \
		background.height=20 \
		click_script="$click_script"
}

active_records() {
	local file="$1"

	awk -F '\t' '
		NR == 1 { next }
		function priority(state) {
			if (state == "needs-help") return 4
			if (state == "needs-attention") return 3
			if (state == "running") return 2
			if (state == "idle") return 1
			return 0
		}
		{
			row_priority = priority($3)
			if (row_priority > 0) {
				printf "%d\t%d\t%s\t%s\t%s\t%s\n", row_priority, NR, $1, $3, $4, $5
			}
		}
	' "$file" | sort -t "$(printf '\t')" -k1,1nr -k2,2n
}

highest_priority_record() {
	active_records "$1" | head -1
}

item_exists() {
	sketchybar --query "$1" >/dev/null 2>&1
}

ensure_item() {
	local item="$1"

	item_exists "$item" || sketchybar --add item "$item" center
}

focus_record() {
	local pane="$1"

	[[ -z "$pane" ]] && return 0
	if command -v tmux >/dev/null 2>&1; then
		tmux select-window -t "$pane" >/dev/null 2>&1 || true
		tmux select-pane -t "$pane" >/dev/null 2>&1 || true
	fi
}

click_script_for_pane() {
	local pane="$1"

	if [[ -n "$pane" ]]; then
		printf 'tmux select-window -t %s; tmux select-pane -t %s' "$pane" "$pane"
	fi
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
			sketchybar --remove "${NAME}.${id}" >/dev/null 2>&1 || true
		fi
	done
}

write_cache() {
	local cache="$1"

	mkdir -p "$(dirname "$cache")"
	printf '%s\n' "$current_ids" >"$cache"
}

render() {
	local file cache records priority row raw_id id state label pane item current_ids

	file="$(state_file)"
	cache="$(cache_file)"
	if [[ ! -r "$file" ]]; then
		current_ids=""
		remove_stale_items "$cache"
		write_cache "$cache"
		sketchybar --set "$NAME" drawing=off
		return 0
	fi

	records="$(active_records "$file")"
	current_ids="$(printf '%s\n' "$records" | awk -F '\t' 'NF { gsub(/[^[:alnum:]_]/, "_", $3); printf "%s%s", sep, $3; sep = " " }')"
	remove_stale_items "$cache"

	if [[ -z "$records" ]]; then
		write_cache "$cache"
		sketchybar --set "$NAME" drawing=off
		return 0
	fi

	sketchybar --set "$NAME" drawing=off
	while IFS=$'\t' read -r priority row raw_id state label pane; do
		[[ -z "$raw_id" ]] && continue
		id="$(sanitize_item_id "$raw_id")"
		item="${NAME}.${id}"
		ensure_item "$item"
		set_item_style "$item" "$state" "${label:-agent}" "$pane"
	done <<<"$records"
	write_cache "$cache"
}

main() {
	case "${SENDER:-}" in
	mouse.clicked)
		record="$(highest_priority_record "$(state_file)" 2>/dev/null || true)"
		[[ -n "$record" ]] && IFS=$'\t' read -r _ _ _ _ _ pane <<<"$record" && focus_record "$pane"
		;;
	*)
		render
		;;
	esac
}

main "$@"
