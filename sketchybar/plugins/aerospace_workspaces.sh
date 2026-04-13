#!/bin/sh

FOCUSED="$FOCUSED_WORKSPACE"

if [ -z "$FOCUSED" ]; then
  FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null)
fi

for name in B T N M I P; do
  if [ "$name" = "$FOCUSED" ]; then
    sketchybar --set "space.$name" background.drawing=on icon.highlight=on
  else
    sketchybar --set "space.$name" background.drawing=off icon.highlight=off
  fi
done
