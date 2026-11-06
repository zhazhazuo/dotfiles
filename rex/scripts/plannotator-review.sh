#!/usr/bin/env bash
#
# plannotator-review — review a document in Plannotator and paste the new
# annotations into an agent's prompt.
#
# The Herdr plugin hands the feedback to a pane through `--deliver-to`, a
# Herdr-only channel. Rex has no plugin channel, so the same hand-off is two
# steps here: Plannotator writes each annotation into its own store, and this
# script reads them back with `--export` and pastes the new ones into the target
# block as one paste event. A paste, not typed keys: a newline delivered as a key
# would submit the agent's prompt instead of adding a line to it.
#
# Usage:
#   plannotator-review.sh <document|-|message> <session_id> <target_block_id>
#
# `-` means the target block shows no document, so its pane text is snapshotted
# into a temporary Markdown file and reviewed instead. `message` reviews the last
# message pi wrote, which is what you want when the pane runs an agent: the pane
# text also carries the prompt box, the status line and the wrap of the terminal.
# Only annotations added during this run are delivered, because the export also
# holds every annotation the document already had.
set -euo pipefail

doc=${1:?document or -}
session=${2:?session}
target=${3:?block}

# The review block starts with the server's PATH, not the login shell's, so
# ~/.local/bin is not guaranteed. Look there before giving up.
if [ -n "${PLANNOTATOR_TUI:-}" ]; then
	tui=$PLANNOTATOR_TUI
elif command -v plannotator-tui >/dev/null 2>&1; then
	tui=$(command -v plannotator-tui)
elif [ -x "$HOME/.local/bin/plannotator-tui" ]; then
	tui=$HOME/.local/bin/plannotator-tui
elif [ -x "$HOME/dotfiles/bin/plannotator-tui" ]; then
	tui=$HOME/dotfiles/bin/plannotator-tui
else
	echo "plannotator-review: plannotator-tui is not installed" >&2
	exit 1
fi

if [ ! -x "$tui" ] && ! command -v "$tui" >/dev/null 2>&1; then
	echo "plannotator-review: $tui cannot be run" >&2
	exit 1
fi

work=$(mktemp -d -t plannotator-review)
trap 'rm -rf "$work"' EXIT
before="$work/before.md"
after="$work/after.md"
docfile=$doc

if [ "$doc" = "message" ]; then
	# The transcript, not the screen: no prompt box, no status line, and no
	# lines broken where the terminal happened to wrap them.
	docfile="$work/message.md"
	if ! "$tui" last --host pi --print >"$docfile" 2>/dev/null || [ ! -s "$docfile" ]; then
		echo "plannotator-review: pi has no message to review here" >&2
		exit 1
	fi
fi

if [ "$doc" = "-" ]; then
	docfile="$work/pane.md"
	if command -v rex >/dev/null 2>&1; then
		{
			printf '# Pane text: %s\n\n' "$(basename "$PWD")"
			rex capture -s "$session" -b "$target" 2>/dev/null || true
		} >"$docfile"
	else
		printf '# Pane text\n\n' >"$docfile"
	fi
fi

if [ ! -e "$docfile" ]; then
	echo "plannotator-review: no such document: $docfile" >&2
	exit 1
fi

"$tui" --export "$docfile" >"$before" 2>/dev/null || true

"$tui" "$docfile" || true

"$tui" --export "$docfile" >"$after" 2>/dev/null || true

# Keep the annotations numbered above the ones that were already there. Diffing
# the two exports would also re-send the header and shift the numbering.
baseline=$(grep -c '^## Annotation [0-9]' "$before" 2>/dev/null || true)
baseline=${baseline:-0}

added=$(awk -v baseline="$baseline" '
	/^## Annotation [0-9]+/ { keep = (substr($3, 1) + 0) > baseline }
	keep { print }
' "$after")

if [ -z "$added" ]; then
	exit 0
fi

printf 'Review feedback from Plannotator:\n\n%s\n' "$added" >"$work/paste.md"

payload=$(jq -nc --arg s "$session" --arg b "$target" --rawfile t "$work/paste.md" \
	'{session_id: $s, block_id: $b, event: {type: "paste", payload: {text: $t}}}')

if ! rex api call block.event "$payload" >/dev/null 2>&1; then
	echo "plannotator-review: could not paste the annotations into $target" >&2
	exit 1
fi

count=$(grep -c '^## Annotation' <<<"$added" || true)
printf 'Pasted %s annotation(s) into the prompt. Press Return to send.\n' "${count:-1}"
