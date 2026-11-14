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
packages="${PI_NODE_MODULES_DIR:-$HOME/.pi/agent/npm/node_modules}"

apply() {
	local package="$1" patch_file="$2" dir="$packages/$1"

	if [[ ! -d "$dir" ]]; then
		printf 'skip %s: not installed\n' "$package"
		return 0
	fi

	# Apple's /usr/bin/patch answers its own "Unreversed (or previously
	# applied) patch detected!" prompt with yes, so a reverse dry-run exits 0
	# on a file the patch never touched, and a plain forward apply reverts a
	# patched file. The check that does not lie: forward-apply with -N, which
	# skips a patch that looks already applied, to a copy, and judge by
	# content.
	local probe probe_dir
	probe=$(mktemp -d "$dir/.apply-probe.XXXXXX")
	probe_dir="$dir/$(basename "$probe")"
	local target patched
	target=$(sed -n 's/^+++ b\///p' "$patch_file" | head -1)
	if [[ -z "$target" ]]; then
		rm -rf "$probe_dir"
		printf 'fail %s: patch declares no target\n' "$(basename "$patch_file")"
		return 1
	fi
	mkdir -p "$probe_dir/$(dirname "$target")"
	cp "$dir/$target" "$probe_dir/$target"
	if (cd "$probe_dir" && patch -p1 -N -s <"$patch_file" >/dev/null 2>&1) \
		&& ! cmp -s "$dir/$target" "$probe_dir/$target"; then
		patched=0
	else
		patched=1
	fi
	rm -rf "$probe_dir"

	if [[ "$patched" == "1" ]]; then
		printf 'ok   %s: already applied\n' "$(basename "$patch_file")"
		return 0
	fi

	(cd "$dir" && patch -p1 -N --silent <"$patch_file")
	printf 'ok   %s: applied to %s\n' "$(basename "$patch_file")" "$package"
}

apply "@juicesharp/rpiv-ask-user-question" \
	"$here/rpiv-ask-user-question-blocked.patch"
