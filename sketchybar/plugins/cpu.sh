#!/bin/sh

CPU_INFO=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%.0f", s}')
CORES=$(sysctl -n hw.ncpu)
CPU_PERCENT=$((CPU_INFO / CORES))
if [ "$CPU_PERCENT" -gt 100 ]; then
  CPU_PERCENT=100
fi

ICON="󰻠"

sketchybar --set "$NAME" icon="$ICON" label="${CPU_PERCENT}%"
