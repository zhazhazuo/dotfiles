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
current_session=""
max_item_width=0
muted=$'\033[38;2;110;115;141m'
accent=$'\033[38;2;166;218;149m'
reset=$'\033[0m'

clamp() {
  local value="$1"
  local min="$2"
  local max="$3"

  if ((value < min)); then
    echo "$min"
  elif ((value > max)); then
    echo "$max"
  else
    echo "$value"
  fi
}

while IFS=$'\t' read -r _ session window_index window_name window_active _; do
  [[ -z "$session" || -z "$window_index" || -z "$window_name" ]] && continue

  if [[ "$session" != "$current_session" ]]; then
    rows="${rows}${session}"$'\t'"${muted}${session}${reset}"$'\n'
    row_count=$((row_count + 1))
    current_session="$session"
    if ((${#session} > max_item_width)); then
      max_item_width=${#session}
    fi
  fi

  marker="  "
  if [[ "$window_active" == "1" ]]; then
    marker="${accent}${reset} "
  fi

  raw_display="  ${window_name} · ${session}"
  display="  ${marker}${window_name} ${muted}· ${session}${reset}"
  rows="${rows}${session}:${window_index}"$'\t'"${display}"$'\n'
  row_count=$((row_count + 1))
  if ((${#raw_display} > max_item_width)); then
    max_item_width=${#raw_display}
  fi
done < <(tmux list-windows -a -F '#{session_last_attached}	#{session_name}	#{window_index}	#{window_name}	#{window_active}	#{window_last_flag}' | sort -t $'\t' -k1,1rn -k2,2 -k3,3n)

if ((row_count == 0)); then
  exit 0
fi

padding="1,2"
if ((row_count <= 6)); then
  padding="1,3"
elif ((row_count >= 14)); then
  padding="0,1"
fi

fzf_args=(
  --reverse
  --exit-0
  --ansi
  --delimiter=$'\t'
  --with-nth=2..
  --accept-nth=1
  --bind=enter:accept-non-empty
  --layout=reverse
  --style=minimal
  --border=none
  --list-border=none
  --input-border=none
  --header-border=none
  --padding="${padding}"
  --no-separator
  --info=inline-right
  --header=" "
  --prompt="  Sessions  "
  --pointer="▌"
  --marker="•"
  --border-label=" tmux session switcher "
  --border-label-pos=3
  --color="fg:#cad3f5,bg:-1,fg+:#f4dbd6,bg+:-1,hl:#8aadf4,hl+:#f5bde6,info:#6e738d,prompt:#8aadf4,pointer:#f5bde6,marker:#a6da95,spinner:#f5bde6,header:#6e738d,border:#6e738d,gutter:-1,label:#6e738d"
)
if [[ "${1:-}" == "--popup" ]]; then
  popup_width="$(clamp $((max_item_width + 14)) 48 84)"
  popup_height="$(clamp $((row_count + 6)) 11 22)"
  fzf_args+=(--tmux="center,${popup_width},${popup_height},border-native")
fi

choice=$(printf '%s' "$rows" | fzf "${fzf_args[@]}")
choice="${choice%%$'\t'*}"

if [[ -n "$choice" ]]; then
  tmux switch-client -t "$choice"
fi
