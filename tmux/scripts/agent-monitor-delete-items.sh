#!/usr/bin/env bash
#
# Delete explicit tmux agent monitor records by id.

set +e +u

usage() {
	cat <<'EOF'
Usage:
  agent-monitor-delete-items.sh <id> [id ...]
  agent-monitor-delete-items.sh --stdin

Deletes exact ids from @agent_monitor_instances and unsets each record's metadata.
With --stdin, ids may be separated by whitespace, commas, or newlines.
EOF
}

tmux_global_option() {
	tmux show-options -gqv "$1" 2>/dev/null || true
}

tmux_set_global_option() {
	tmux set-option -gq "$1" "$2" 2>/dev/null || true
}

tmux_unset_global_option() {
	tmux set-option -guq "$1" 2>/dev/null || true
}

contains_id() {
	local needle="$1" item

	for item in $delete_ids; do
		[[ "$item" == "$needle" ]] && return 0
	done

	return 1
}

read_delete_ids() {
	case "${1:-}" in
	--stdin)
		tr ',[:space:]' ' ' | xargs 2>/dev/null
		;;
	*)
		printf '%s\n' "$*"
		;;
	esac
}

unset_record() {
	local id="$1" prefix suffix

	prefix="@agent_monitor_${id}"
	for suffix in name state label pane session_id updated_at; do
		tmux_unset_global_option "${prefix}_${suffix}"
	done
}

refresh_status() {
	local script_dir

	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
	"${script_dir}/agent-status.sh" --refresh >/dev/null 2>&1 || true
	"${script_dir}/agent-monitor-state.sh" --refresh >/dev/null 2>&1 || true
	tmux refresh-client -S 2>/dev/null || true
}

main() {
	local delete_ids instances id next removed

	case "${1:-}" in
	-h|--help)
		usage
		return 0
		;;
	"")
		usage >&2
		return 2
		;;
	esac

	delete_ids="$(read_delete_ids "$@")"
	instances="$(tmux_global_option @agent_monitor_instances)"

	for id in $instances; do
		if contains_id "$id"; then
			unset_record "$id"
			removed="${removed:+$removed }$id"
		else
			next="${next:+$next }$id"
		fi
	done

	tmux_set_global_option @agent_monitor_instances "$next"
	refresh_status

	printf 'removed=%s\n' "$removed"
	printf 'remaining=%s\n' "$next"
}

main "$@"
