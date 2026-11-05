#!/usr/bin/env bash
#
# install.sh — load the Rex watcher under launchd, or reload it.
#
# A running job keeps whatever adapter it read when it started. launchd's
# WatchPaths starts a job that is not running, so it cannot replace this one:
# the job is always alive by design. Editing adapters/rex.sh therefore needs the
# restart this script does.
set -euo pipefail

label=local.agent-monitor.rex
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
plist="$script_dir/$label.plist"
domain="gui/$(id -u)"

if launchctl print "$domain/$label" >/dev/null 2>&1; then
	launchctl kickstart -k "$domain/$label"
	printf 'reloaded %s\n' "$label"
else
	launchctl bootstrap "$domain" "$plist"
	printf 'loaded %s\n' "$label"
fi
