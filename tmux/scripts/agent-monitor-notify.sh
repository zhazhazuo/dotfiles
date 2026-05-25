#!/usr/bin/env bash
#
# Send macOS notifications for agent states that need user attention.

set +e +u

agent_name="${1:-agent}"
state="${2:-}"
label="${3:-agent}"

tmux_global_option() {
	tmux show-options -gqv "$1" 2>/dev/null || true
}

option_or_default() {
	local option="$1"
	local default="$2"
	local value

	value="$(tmux_global_option "$option")"
	printf '%s' "${value:-$default}"
}

is_disabled() {
	case "$1" in
	off|false|0|no)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

frontmost_app() {
	if [[ -n "${AGENT_MONITOR_FRONT_APP:-}" ]]; then
		printf '%s' "$AGENT_MONITOR_FRONT_APP"
		return 0
	fi

	osascript -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || true
}

is_tmux_app() {
	local app="$1"
	local tmux_apps item

	tmux_apps="$(option_or_default @agent_monitor_notify_tmux_apps "Ghostty Terminal iTerm2 WezTerm kitty Alacritty")"
	for item in $tmux_apps; do
		[[ "$app" == "$item" ]] && return 0
	done

	return 1
}

notification_text() {
	case "$state" in
	needs-help)
		title="${label} needs help"
		body="${agent_name} is waiting for input or permission."
		;;
	needs-attention)
		title="${label} finished"
		body="${agent_name} needs your attention."
		;;
	*)
		return 1
		;;
	esac
}

send_notification() {
	osascript - "$title" "$body" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
	display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
}

main() {
	local enabled app title body

	enabled="$(option_or_default @agent_monitor_notify_enabled on)"
	is_disabled "$enabled" && exit 0

	notification_text || exit 0

	app="$(frontmost_app)"
	if is_tmux_app "$app"; then
		exit 0
	fi

	send_notification
}

main
exit 0
