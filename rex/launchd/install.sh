#!/usr/bin/env bash
#
# install.sh — load the listing daemon under launchd, or reload it.
#
# A running job keeps whatever script it read when it started, so editing
# scripts/listing.lua needs the restart this script does. launchd's WatchPaths
# starts a job that is not running, and this one is always alive by design.
set -euo pipefail

label=local.rex-listing
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
plist="$script_dir/$label.plist"
domain="gui/$(id -u)"

mkdir -p "$HOME/.cache/rex"

if launchctl print "$domain/$label" >/dev/null 2>&1; then
	launchctl kickstart -k "$domain/$label"
	printf 'reloaded %s\n' "$label"
else
	launchctl bootstrap "$domain" "$plist"
	printf 'loaded %s\n' "$label"
fi
