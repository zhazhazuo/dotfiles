#!/usr/bin/env bash
#
# Map Codex hook events onto the tmux agent monitor event contract.

set +e +u

event_name="${1:-}"

if [[ -z "$event_name" ]]; then
	input="$(cat 2>/dev/null || true)"
	event_name="$(printf '%s' "$input" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
	printf '%s' "$input" | "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/agent-monitor-event.sh" codex "$event_name" >/dev/null 2>&1 || true
	exit 0
fi

"$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/agent-monitor-event.sh" codex "$event_name" >/dev/null 2>&1 || true

exit 0
