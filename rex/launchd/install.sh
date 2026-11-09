#!/usr/bin/env bash
#
# install.sh — load the Rex daemons under launchd, or reload them.
#
# Two jobs run here: the listing that the Raycast view reads, and the golden
# ratio resize that follows the focus. A running job keeps the script it read
# when it started, so editing one of those scripts needs the restart this script
# does. launchd's WatchPaths only starts a job that is not running, and these are
# always alive by design.
#
# The plists are linked into ~/Library/LaunchAgents as well, because a job loaded
# straight from this folder lives only until the next logout.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
agents="$HOME/Library/LaunchAgents"
domain="gui/$(id -u)"

mkdir -p "$HOME/.cache/rex" "$agents"

disabled_list=$(launchctl print-disabled "$domain" 2>/dev/null || true)

for plist in "$script_dir"/local.rex-*.plist; do
	label=$(basename "$plist" .plist)
	ln -sf "$plist" "$agents/$label.plist"
	# A label that the user turned off stays off: `launchctl bootstrap` fails on a
	# disabled label, and a daemon someone stopped must not come back here.
	if printf '%s\n' "$disabled_list" | grep -Eq "\"$label\" => (disabled|true)"; then
		printf 'skipped %s (turned off)\n' "$label"
		continue
	fi
	if launchctl print "$domain/$label" >/dev/null 2>&1; then
		launchctl kickstart -k "$domain/$label"
		printf 'reloaded %s\n' "$label"
	else
		launchctl bootstrap "$domain" "$agents/$label.plist"
		printf 'loaded %s\n' "$label"
	fi
done
