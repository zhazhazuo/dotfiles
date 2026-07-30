#!/usr/bin/env bash
#
# agent-monitor/adapters/pi.sh — Pi agent adapter
#
# Called by the Pi tmux-monitor extension.
# Reads event JSON from stdin, normalizes, calls reconcile.
#
# Usage: echo '{"cwd":"/tmp","session_id":"..."}' | pi.sh <event>

set -euo pipefail

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${ADAPTER_DIR}/../bin/agent-monitor"

event="${1:-}"
json="$(cat 2>/dev/null || true)"

# Reject pi-subagents child processes (canonical guard).
# pi-subagents sets these env vars on every child Pi process it spawns.
# The adapter inherits the Pi process environment, so they are visible here.
if [[ -n "${PI_SUBAGENT_PARENT_SESSION:-}" || -n "${PI_SUBAGENT_CHILD:-}" ]]; then
	exit 0
fi

# Reject subagent sessions (defense-in-depth backstop: legacy run-N layout)
session_id=$(printf '%s' "$json" | jq -r '.session_id // empty' 2>/dev/null || true)
if printf '%s' "$session_id" | grep -qE '/run-[0-9]+/session\.jsonl$'; then
	exit 0
fi

# Map Pi-specific events to generic names
case "$event" in
AgentStart | agent_start) event="RunStart" ;;
AgentEnd | agent_end) event="TurnComplete" ;;
agent_settled) event="TurnComplete" ;;
SessionShutdown | session_shutdown)
	# Remove agent from monitor on shutdown
	"$BIN" remove "${TMUX_PANE:-}" 2>/dev/null || true
	exit 0
	;;
esac

# Call reconcile
"$BIN" reconcile pi "$event" "$json"
