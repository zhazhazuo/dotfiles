#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/.tmux.conf"

assert_contains() {
	local needle="$1"
	local name="$2"

	if ! grep -Fqx "$needle" "$CONFIG"; then
		printf 'not ok - %s\n' "$name" >&2
		printf 'missing: %s\n' "$needle" >&2
		exit 1
	fi

	printf 'ok - %s\n' "$name"
}

assert_contains 'bind-key s run-shell -b "~/dotfiles/tmux/scripts/session-switcher.sh --popup"' 'prefix-s uses fzf tmux popup session search'
