#!/usr/bin/env bash
#
# Tmux-facing agent state contract helper.
#
# Usage from an agent hook:
#   agent-state-hook.sh <agent-name> <state> [instances]
#
# States:
#   running | needs-input | idle | failed

set +e +u

agent_name="${1:-agent}"
agent_state="${2:-idle}"
agent_instances="${3:-1}"

case "$agent_state" in
	run | running | work | working | busy | thinking | executing | tool | tools)
		agent_state="running"
		;;
	input | needsinput | needs-input | confirm | approval | blocked)
		agent_state="needs-input"
		;;
	fail | failed | failure | error)
		agent_state="failed"
		;;
	wait | waiting | idle | inactive | ready | done | complete | completed | *)
		agent_state="idle"
		;;
esac

if [[ -z "${TMUX_PANE:-}" ]] || ! command -v tmux >/dev/null 2>&1; then
	exit 0
fi

tmux set-option -pq -t "$TMUX_PANE" @agent_name "$agent_name" 2>/dev/null || true
tmux set-option -pq -t "$TMUX_PANE" @agent_state "$agent_state" 2>/dev/null || true
tmux set-option -pq -t "$TMUX_PANE" @agent_instances "$agent_instances" 2>/dev/null || true

exit 0
