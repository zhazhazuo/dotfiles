#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/.tmux.conf"

assert_contains() {
	local needle="$1"
	local name="$2"

	if ! grep -Fqx "$needle" "$CONFIG"; then
		printf 'not ok - %s\n' "$name" >&2
		printf 'missing: %s\n' "$needle" >&2
		exit 1
	fi

	printf 'ok - %s\n' "$name"
}

assert_contains_substring() {
	local needle="$1"
	local name="$2"

	if ! grep -Fq "$needle" "$CONFIG"; then
		printf 'not ok - %s\n' "$name" >&2
		printf 'missing substring: %s\n' "$needle" >&2
		exit 1
	fi

	printf 'ok - %s\n' "$name"
}

assert_not_contains_substring() {
	local needle="$1"
	local name="$2"

	if grep -Fq "$needle" "$CONFIG"; then
		printf 'not ok - %s\n' "$name" >&2
		printf 'unexpected substring: %s\n' "$needle" >&2
		exit 1
	fi

	printf 'ok - %s\n' "$name"
}

assert_contains 'bind-key s run-shell -b "~/dotfiles/tmux/scripts/session-switcher.sh --popup"' 'prefix-s uses fzf tmux popup session search'
assert_contains 'bind-key -n MouseDown1Status if -F "#{==:#{mouse_status_range},pane}" "select-pane -t =" "if -F '\''#{==:#{mouse_status_range},window}'\'' '\''select-window -t ='\''"' 'status click selects agent panes without stealing window clicks'
assert_contains 'set -g @agent_monitor_notify_enabled "on"' 'agent monitor notifications are configurable'
assert_contains 'set -g @agent_monitor_notify_tmux_apps "Ghostty Terminal iTerm2 WezTerm kitty Alacritty"' 'agent monitor skips notifications in terminal apps'
assert_contains 'set -g @agent_monitor_status ""' 'agent monitor status option is initialized'
assert_contains 'set-hook -g pane-exited '\''run-shell -b "~/dotfiles/tmux/scripts/agent-monitor-prune.sh"'\''' 'pane exit prunes agent monitor records'
assert_contains 'set-hook -g after-kill-pane '\''run-shell -b "~/dotfiles/tmux/scripts/agent-monitor-prune.sh"'\''' 'pane kill prunes agent monitor records'
assert_contains 'set-hook -g after-kill-window '\''run-shell -b "~/dotfiles/tmux/scripts/agent-monitor-prune.sh"'\''' 'window kill prunes agent monitor records'
assert_contains_substring '#{E:@agent_monitor_status}' 'status format reads pre-rendered agent monitor option'
assert_not_contains_substring '#(~/dotfiles/tmux/scripts/agent-status.sh)' 'status format does not depend on delayed shell command output'
