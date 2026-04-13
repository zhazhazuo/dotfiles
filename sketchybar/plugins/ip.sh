#!/bin/sh

IP="$(ipconfig getifaddr en0 2>/dev/null || echo "N/A")"

sketchybar --set "$NAME" label="$IP"
