#!/usr/bin/env bash
#
# Print the current tmux agent monitor records.

set +e +u

tmux_global_option() {
	tmux show-options -gqv "$1" 2>/dev/null || true
}

main() {
	local instances id prefix name state label pane session_id updated_at

	instances="$(tmux_global_option @agent_monitor_instances)"
	printf 'id\tname\tstate\tlabel\tpane\tsession_id\tupdated_at\n'

	for id in $instances; do
		prefix="@agent_monitor_${id}"
		name="$(tmux_global_option "${prefix}_name")"
		state="$(tmux_global_option "${prefix}_state")"
		label="$(tmux_global_option "${prefix}_label")"
		pane="$(tmux_global_option "${prefix}_pane")"
		session_id="$(tmux_global_option "${prefix}_session_id")"
		updated_at="$(tmux_global_option "${prefix}_updated_at")"

		printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$id" "$name" "$state" "$label" "$pane" "$session_id" "$updated_at"
	done
}

main "$@"
