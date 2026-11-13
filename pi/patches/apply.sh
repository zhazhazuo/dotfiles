#!/usr/bin/env bash
#
# apply.sh — apply the local patches to installed pi packages.
#
# Why these exist: pi reports `blocked` over OSC 7501 only for a UI component
# that declares it, and @juicesharp/rpiv-ask-user-question mounts the
# questionnaire without that option. So a waiting `ask_user_question` leaves pi
# `working`, and a terminal that renders program status (Rex) never shows the
# red needs-help state. agent-monitor/adapters/rex.sh already maps `blocked` to
# needs-help; only the report is missing.
#
# A package update replaces the patched file, so run this again after
# `pi update`. Each patch is checked before it is applied, so a second run
# changes nothing, and a version that already carries the change is left alone.
#
# Usage: pi/patches/apply.sh
set -euo pipefail

here=$(cd -- "$(dirname -- "$0")" && pwd)
packages="$HOME/.pi/agent/npm/node_modules"

apply() {
	local package="$1" patch_file="$2" dir="$packages/$1"

	if [[ ! -d "$dir" ]]; then
		printf 'skip %s: not installed\n' "$package"
		return 0
	fi

	if (cd "$dir" && patch -p1 --dry-run --reverse --silent <"$patch_file" >/dev/null 2>&1); then
		printf 'ok   %s: already applied\n' "$(basename "$patch_file")"
		return 0
	fi

	(cd "$dir" && patch -p1 --silent <"$patch_file")
	printf 'ok   %s: applied to %s\n' "$(basename "$patch_file")" "$package"
}

apply "@juicesharp/rpiv-ask-user-question" \
	"$here/rpiv-ask-user-question-blocked.patch"
