#!/usr/bin/env bash
#
# agent-monitor/adapters/codex.sh — Codex agent adapter
#
# Called by Codex hook events.
# Reads event JSON from stdin, normalizes, calls reconcile.
#
# Usage: echo '{"hook_event_name":"UserPromptSubmit",...}' | codex.sh [event]

set -euo pipefail

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${ADAPTER_DIR}/../bin/agent-monitor"

# Event can come from arg or from JSON payload
event="${1:-}"
json="$(cat 2>/dev/null || true)"

if [[ -z "$event" ]]; then
	# Extract from JSON payload
	event=$(printf '%s' "$json" | jq -r '.hook_event_name // empty' 2>/dev/null || true)
fi

[[ -z "$event" ]] && exit 0

# Map Codex-specific events to generic names
case "$event" in
UserPromptSubmit) event="PromptSubmit" ;;
PostToolUse) event="ToolEnd" ;;
PreToolUse)
	# Check if this is a permission-requiring tool
	tool_name=$(printf '%s' "$json" | jq -r '.tool_name // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]')
	case "$tool_name" in
	*request_user_input* | *ask_question* | *ask_user* | *request_permission* | *request_approval*)
		event="PermissionRequest"
		;;
	*)
		sandbox=$(printf '%s' "$json" | jq -r '.tool_input.sandbox_permissions // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]')
		if [[ "$sandbox" == "require_escalated" ]]; then
			event="PermissionRequest"
		else
			event="ToolStart"
		fi
		;;
	esac
	;;
PermissionRequest) event="PermissionRequest" ;;
Stop) event="Stop" ;;
esac

"$BIN" reconcile codex "$event" "$json"
