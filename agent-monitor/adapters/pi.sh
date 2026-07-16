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

# Reject subagent sessions (defense-in-depth)
session_id=$(printf '%s' "$json" | jq -r '.session_id // empty' 2>/dev/null || true)
if printf '%s' "$session_id" | grep -qE '/run-[0-9]+/session\.jsonl$'; then
	exit 0
fi

# Map Pi-specific events to generic names
case "$event" in
AgentStart | agent_start) event="RunStart" ;;
AgentEnd | agent_end) event="TurnComplete" ;;
agent_settled) event="TurnComplete" ;;
SessionShutdown | session_shutdown) event="SessionStart" ;;
esac

# Call reconcile
"$BIN" reconcile pi "$event" "$json"
