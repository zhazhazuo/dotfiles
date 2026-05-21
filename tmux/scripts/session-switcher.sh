#!/usr/bin/env bash
#
# Fast tmux session switcher using fzf
#
# Lists windows grouped by session, sorted by session recency, and switches to
# the selected window.
#
# Usage:
#   Bind to a key in tmux.conf:
#     bind C-j run-shell -b "tmux-session-switcher --popup"
#
# Requirements: fzf

rows=""
row_count=0
max_name_width=0
current_session=""
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while IFS=$'\t' read -r _ session window_index window_name window_active _; do
  [[ -z "$session" || -z "$window_index" || -z "$window_name" ]] && continue

  if [[ "$session" != "$current_session" ]]; then
    rows="${rows}${session}"$'\t'"${session}"$'\n'
    row_count=$((row_count + 1))
    current_session="$session"
    if ((${#session} > max_name_width)); then
      max_name_width=${#session}
    fi
  fi

  marker="  "
  if [[ "$window_active" == "1" ]]; then
    marker=" "
  fi

  display="  ${marker}${session} / ${window_name}"
  rows="${rows}${session}:${window_index}"$'\t'"${display}"$'\n'
  row_count=$((row_count + 1))
  if ((${#display} > max_name_width)); then
    max_name_width=${#display}
  fi
done < <(tmux list-windows -a -F '#{session_last_attached}	#{session_name}	#{window_index}	#{window_name}	#{window_active}	#{window_last_flag}' | sort -t $'\t' -k1,1rn -k2,2 -k3,3n)

if ((row_count == 0)); then
  exit 0
fi

fzf_args=(
  --reverse
  --exit-0
  --delimiter=$'\t'
  --with-nth=2..
  --accept-nth=1
  --bind=enter:accept-non-empty
  --preview="${script_dir}/session-preview.sh {1}"
  --preview-window=right,70%,border-left,wrap
)
if [[ "${1:-}" == "--popup" ]]; then
  fzf_args+=(--tmux=center,60%,60%,border-native)
fi

choice=$(printf '%s' "$rows" | fzf "${fzf_args[@]}")
choice="${choice%%$'\t'*}"

if [[ -n "$choice" ]]; then
  tmux switch-client -t "$choice"
fi
