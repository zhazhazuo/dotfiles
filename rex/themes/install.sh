#!/bin/sh
# install.sh — put this directory's Rex themes into Rex, then select one.
#
# The theme files here are the source. Rex keeps an imported copy of each theme in
# its own settings, together with the id of the theme it shows, so a new machine
# needs one import and one selection before it looks the same as this one. This
# script does both, and repeats nothing: a theme whose name is already imported is
# left alone, so running it twice changes nothing.
#
# Usage:
#   install.sh                                   # import missing themes, select "Inkstone Xuanmo"
#   install.sh --dry-run                         # print the plan, change nothing
#   install.sh --select-only                     # select only, import nothing
#   THEME_NAME="Inkstone Xuanmo Dimmed" install.sh
#
# The selection goes through Rex's own action, so the colour change applies at once
# instead of waiting for the next launch.
#
# Regenerate the theme files first with sync-inkstone.sh when the palette moves.

set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
theme_name=${THEME_NAME:-Inkstone Xuanmo}

mode=full
for argument in "$@"; do
	case "$argument" in
	--dry-run) mode=dry ;;
	--select-only) mode=select ;;
	*)
		printf 'unknown argument: %s\n' "$argument" >&2
		exit 2
		;;
	esac
done

command -v rex >/dev/null 2>&1 || {
	printf 'rex is not on PATH\n' >&2
	exit 1
}

# The names Rex has imported, one per line. Empty when its settings hold none.
imported_names() {
	defaults export com.superlogical.rex - 2>/dev/null |
		python3 -c '
import json, plistlib, sys

try:
    settings = plistlib.loads(sys.stdin.buffer.read())
except Exception:
    sys.exit(0)

raw = settings.get("Workspace.customThemes")
if not raw:
    sys.exit(0)

try:
    themes = json.loads(raw)
except Exception:
    sys.exit(0)

for theme in themes:
    name = theme.get("name")
    if isinstance(name, str):
        print(name)
'
}

present=$(imported_names)

for file in "$dir"/*; do
	[ -f "$file" ] || continue
	name=$(basename "$file")
	case "$name" in
	*.sh) continue ;;
	esac

	if printf '%s\n' "$present" | grep -qxF "$name"; then
		printf 'skip %s (already imported)\n' "$name"
		continue
	fi

	case "$mode" in
	dry)
		printf 'import %s\n' "$name"
		continue
		;;
	select)
		printf 'skip %s (select only)\n' "$name"
		continue
		;;
	esac

	rex do client.theme.import path="$file"
	printf 'imported %s\n' "$name"
done

if [ "$mode" = dry ]; then
	printf 'select %s\n' "$theme_name"
	exit 0
fi

rex do client.theme.change name="$theme_name"
printf 'selected %s\n' "$theme_name"

current=$(defaults read com.superlogical.rex Workspace.darkThemeID 2>/dev/null || true)
[ -n "$current" ] && printf 'dark theme id: %s\n' "$current"
