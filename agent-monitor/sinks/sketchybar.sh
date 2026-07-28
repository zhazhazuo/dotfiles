#!/bin/sh

set -eu

STATE_FILE="${AGENT_MONITOR_STATE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/agent-monitor/state.tsv}"
CACHE_FILE="${AGENT_MONITOR_SKETCHYBAR_CACHE:-/tmp/agent_monitor_items.cache}"

if [ -z "$STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

mkdir -p "$(dirname "$CACHE_FILE")"

# Read current state from TSV file (skip header), sort by updated_at descending
TMP_CURRENT=$(mktemp)
tail -n +2 "$STATE_FILE" | sort -t$'\t' -k7 -rn > "$TMP_CURRENT"

# Read cached items
CACHED_ITEMS=""
if [ -f "$CACHE_FILE" ]; then
    CACHED_ITEMS=$(cat "$CACHE_FILE")
fi

# Remove stale items
for cached in $CACHED_ITEMS; do
    if ! grep -q "^$cached	" "$TMP_CURRENT"; then
        sketchybar --remove "agent_monitor.$cached"
    fi
done

# Hide the parent item
sketchybar --set "$NAME" drawing=off

# Process current items in order
while IFS=$'\t' read -r id name state label pane session_id updated_at; do
    [ -z "$id" ] && continue

    case "$state" in
        running)
            BG_COLOR="0xff238636"
            LABEL_COLOR="0xffffffff"
            BG_DRAWING="on"
            ;;
        idle)
            BG_COLOR="0x00000000"
            LABEL_COLOR="0xffaaaaaa"
            BG_DRAWING="off"
            ;;
        needs-help)
            BG_COLOR="0xffc0392b"
            LABEL_COLOR="0xffffffff"
            BG_DRAWING="on"
            ;;
        needs-attention)
            BG_COLOR="0xff1f6feb"
            LABEL_COLOR="0xffffffff"
            BG_DRAWING="on"
            ;;
        *)
            BG_COLOR="0x00000000"
            LABEL_COLOR="0xffffffff"
            BG_DRAWING="off"
            ;;
    esac

    CLICK_SCRIPT=""
    case "$pane" in
        %*)
            CLICK_SCRIPT="tmux select-window -t $pane; tmux select-pane -t $pane"
            ;;
        w*:p*)
            CLICK_SCRIPT="herdr agent focus $pane"
            ;;
    esac

    sketchybar --add item "agent_monitor.$id" center
    if [ -n "$CLICK_SCRIPT" ]; then
        sketchybar --set "agent_monitor.$id" drawing=on icon.drawing=off label="$label" label.color="$LABEL_COLOR" background.drawing="$BG_DRAWING" background.color="$BG_COLOR" background.corner_radius=5 background.height=20 click_script="$CLICK_SCRIPT"
    else
        sketchybar --set "agent_monitor.$id" drawing=on icon.drawing=off label="$label" label.color="$LABEL_COLOR" background.drawing="$BG_DRAWING" background.color="$BG_COLOR" background.corner_radius=5 background.height=20
    fi
done < "$TMP_CURRENT"

# Update cache
cut -f1 "$TMP_CURRENT" > "$CACHE_FILE"

rm -f "$TMP_CURRENT"