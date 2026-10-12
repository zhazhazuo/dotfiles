#!/bin/sh
# Herdr tab-bar segment: the focused pane's current pi step.
#
# Reads the `pi_step` pane-metadata token reported by the pi extension
# ~/.pi/agent/extensions/herdr-pi-step.ts (which in turn resolves the step from
# the pi session: todo in-progress item -> running tool -> session name).
#
# Wired in config.toml:
#   ui.tab_bar_right = [{ type = "command", command = "~/.config/herdr/status-pi-step.sh", ... }]
#
# Herdr runs this with HERDR_ACTIVE_PANE_ID for the focused pane. Prints nothing
# when the token is absent, which makes Herdr hide the segment.

set -eu

pane_id="${HERDR_ACTIVE_PANE_ID:-}"
if [ -z "$pane_id" ]; then
	# No server-provided context (manual run): ask for the UI-focused pane.
	pane_id="$(herdr pane current 2>/dev/null | jq -r '.result.pane.pane_id // empty')"
	[ -n "$pane_id" ] || exit 0
fi

step="$(herdr pane get "$pane_id" 2>/dev/null | jq -r '.result.pane.tokens.pi_step // empty')"
[ -n "$step" ] || exit 0

# Herdr clips tab-bar text at 80 chars; clip here so the clip stays visible.
printf '%s\n' "$(printf '%s' "$step" | cut -c1-78)"
