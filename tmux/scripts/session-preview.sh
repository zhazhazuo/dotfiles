#!/usr/bin/env bash
#
# Render previews for the tmux session switcher.

set -euo pipefail

target="${1:-}"
if [[ -z "$target" ]]; then
  exit 0
fi

if [[ "$target" == *:* ]]; then
  tmux capture-pane -ep -t "$target" -S -80
  exit 0
fi
