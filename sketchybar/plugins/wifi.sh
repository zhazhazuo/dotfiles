#!/bin/sh

WIFI_ICON="󰤨"
OFF_ICON="󰤭"

WIFI_STATUS=$(networksetup -getairportport en0 2>/dev/null | grep -c "On")
if [ "$WIFI_STATUS" -eq 0 ]; then
  WIFI_STATUS=$(system_profiler SPAirPortDataType 2>/dev/null | grep -c "Wi-Fi: On")
fi

if [ "$WIFI_STATUS" -gt 0 ]; then
  NETWORK=$(networksetup -getairportnetwork en0 2>/dev/null | sed 's/Current Wi-Fi Network: //')
  if [ -n "$NETWORK" ]; then
    sketchybar --set "$NAME" icon="$WIFI_ICON" label="$NETWORK"
  else
    sketchybar --set "$NAME" icon="$WIFI_ICON" label=""
  fi
else
  sketchybar --set "$NAME" icon="$OFF_ICON" label=""
fi
