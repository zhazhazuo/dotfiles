#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/.tmux.conf"
BINDS="$ROOT_DIR/binds.conf"
THEME="$ROOT_DIR/theme.conf"
STATUS="$ROOT_DIR/status.conf"
PLUGINS="$ROOT_DIR/plugins.conf"

assert_file_contains() {
	local file="$1"
	local needle="$2"
	local name="$3"

	if ! grep -Fqx "$needle" "$file"; then
		printf 'not ok - %s\n' "$name" >&2
		printf 'missing: %s\n' "$needle" >&2
		exit 1
	fi

	printf 'ok - %s\n' "$name"
}

assert_file_contains_substring() {
	local file="$1"
	local needle="$2"
	local name="$3"

	if ! grep -Fq "$needle" "$file"; then
		printf 'not ok - %s\n' "$name" >&2
		printf 'missing substring: %s\n' "$needle" >&2
		exit 1
	fi

	printf 'ok - %s\n' "$name"
}

assert_file_not_contains_substring() {
	local file="$1"
	local needle="$2"
	local name="$3"

	if grep -Fq "$needle" "$file"; then
		printf 'not ok - %s\n' "$name" >&2
		printf 'unexpected substring: %s\n' "$needle" >&2
		exit 1
	fi

	printf 'ok - %s\n' "$name"
}

assert_line_order() {
	local file="$1"
	local first="$2"
	local second="$3"
	local name="$4"
	local first_line
	local second_line

	first_line="$(grep -nF "$first" "$file" | head -n1 | cut -d: -f1)"
	second_line="$(grep -nF "$second" "$file" | head -n1 | cut -d: -f1)"

	if [[ -z "$first_line" || -z "$second_line" || "$first_line" -ge "$second_line" ]]; then
		printf 'not ok - %s\n' "$name" >&2
		printf 'expected order:\n%s\n%s\n' "$first" "$second" >&2
		exit 1
	fi

	printf 'ok - %s\n' "$name"
}

assert_file_contains "$CONFIG" 'source-file ~/dotfiles/tmux/options.conf' 'aggregator sources options.conf'
assert_file_contains "$CONFIG" 'source-file ~/dotfiles/tmux/binds.conf' 'aggregator sources binds.conf'
assert_file_contains "$CONFIG" 'source-file ~/dotfiles/tmux/theme.conf' 'aggregator sources theme.conf'
assert_file_contains "$CONFIG" 'source-file ~/dotfiles/tmux/status.conf' 'aggregator sources status.conf'
assert_file_contains "$CONFIG" 'source-file ~/dotfiles/tmux/plugins.conf' 'aggregator sources plugins.conf'

assert_file_contains "$BINDS" 'bind-key s run-shell -b "~/dotfiles/tmux/scripts/session-switcher.sh --popup"' 'prefix-s uses fzf tmux popup session search'
assert_file_contains "$THEME" 'bind-key -n MouseDown1Status if -F "#{==:#{mouse_status_range},pane}" "select-pane -t =" "if -F '\''#{==:#{mouse_status_range},window}'\'' '\''select-window -t ='\''"' 'status click selects agent panes without stealing window clicks'
assert_file_contains "$THEME" 'set -g @agent_monitor_notify_enabled "on"' 'agent monitor notifications are configurable'
assert_file_contains "$THEME" 'set -g @agent_monitor_notify_tmux_apps "Ghostty Terminal iTerm2 WezTerm kitty Alacritty"' 'agent monitor skips notifications in terminal apps'
assert_file_contains "$THEME" 'set -g @agent_monitor_status ""' 'agent monitor status option is initialized'
assert_file_contains "$THEME" 'set-hook -g pane-exited '\''run-shell -b "~/dotfiles/bin/agent-monitor prune"'\''' 'pane exit prunes agent monitor records'
assert_file_contains "$THEME" 'set-hook -g after-kill-pane '\''run-shell -b "~/dotfiles/bin/agent-monitor prune"'\''' 'pane kill prunes agent monitor records'
assert_file_not_contains_substring "$THEME" 'after-kill-window' 'theme does not use invalid after-kill-window hook'
assert_file_contains "$THEME" 'set -g display-panes-colour "#6c7086"' 'pane number colour uses literal theme value'
assert_file_contains "$THEME" 'set -g display-panes-active-colour "#fab387"' 'active pane number colour uses literal theme value'
assert_file_contains_substring "$STATUS" '#{E:@agent_monitor_status}' 'status format reads pre-rendered agent monitor option'
assert_file_not_contains_substring "$STATUS" '#(~/dotfiles/tmux/scripts/agent-status.sh)' 'status format does not depend on delayed shell command output'
assert_file_contains_substring "$PLUGINS" "set -g @plugin 'tmux-plugins/tmux-continuum'" 'continuum plugin is configured'
assert_line_order "$PLUGINS" "set -g @plugin 'tmux-plugins/tpm'" "set -g @plugin 'tmux-plugins/tmux-continuum'" 'continuum is last in the TPM plugin list'
