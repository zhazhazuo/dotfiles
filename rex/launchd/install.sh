#!/usr/bin/env bash
#
# install.sh — load the listing daemon under launchd, or reload it.
#
# A running job keeps whatever script it read when it started, so editing
# scripts/listing.lua needs the restart this script does. launchd's WatchPaths
# starts a job that is not running, and this one is always alive by design.
#
# The plist is linked into ~/Library/LaunchAgents as well, because a job loaded
# straight from this folder lives only until the next logout, and a job that is
# not running leaves the listing frozen at its last write.
set -euo pipefail

label=local.rex-listing
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
plist="$script_dir/$label.plist"
agents="$HOME/Library/LaunchAgents"
domain="gui/$(id -u)"

mkdir -p "$HOME/.cache/rex" "$agents"
ln -sf "$plist" "$agents/$label.plist"

if launchctl print "$domain/$label" >/dev/null 2>&1; then
	launchctl kickstart -k "$domain/$label"
	printf 'reloaded %s\n' "$label"
else
	launchctl bootstrap "$domain" "$agents/$label.plist"
	printf 'loaded %s\n' "$label"
fi
