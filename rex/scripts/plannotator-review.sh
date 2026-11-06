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
#   plannotator-review.sh <document|-|message|pick> <session_id> <target_block_id>
#
# `-` means the target block shows no document, so its pane text is snapshotted
# into a temporary Markdown file and reviewed instead. `message` reviews the last
# message pi wrote, and `pick` lists that transcript's messages so one of them can
# be chosen. Both matter when the pane runs an agent: the pane text also carries
# the prompt box, the status line and the wrap of the terminal.
#
# The messages come from pi's own transcript, which records the working directory
# in its first line: the pane's directory picks the transcript, so a pane running
# pi in this folder reviews this folder's conversation.
#
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

# pi's own transcript of this folder: the newest session file that names it.
pick_transcript() {
	local cwd="$1"
	python3 - "$cwd" <<'PY'
import json, os, sys

cwd = sys.argv[1]
root = os.environ.get("PLANNOTATOR_PI_SESSIONS") or os.path.expanduser("~/.pi/agent/sessions")


def header_cwd(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return json.loads(handle.readline()).get("cwd")
    except Exception:
        return None


files = []
for folder in sorted(os.listdir(root)) if os.path.isdir(root) else []:
    directory = os.path.join(root, folder)
    if not os.path.isdir(directory):
        continue
    files += [os.path.join(directory, name) for name in sorted(os.listdir(directory)) if name.endswith(".jsonl")]

matching = [path for path in files if header_cwd(path) == cwd]
pool = matching or files
if not pool:
    sys.exit(4)
print(max(pool, key=os.path.getmtime))
PY
}

# The assistant messages of a transcript, newest first, one file each, printed as
# "path<TAB>time<TAB>first line" for the picker. The path is the first field so
# the preview is a bare `cat` of it, and so the chosen line names its own file.
list_messages() {
	local transcript="$1" out_dir="$2" limit="$3"
	mkdir -p "$out_dir"
	python3 - "$transcript" "$out_dir" "$limit" <<'PY'
import json, os, sys
from datetime import datetime

transcript, out_dir, limit = sys.argv[1], sys.argv[2], int(sys.argv[3])

found = []
with open(transcript, encoding="utf-8", errors="replace") as handle:
    for line in handle:
        try:
            record = json.loads(line)
        except Exception:
            continue
        if record.get("type") != "message":
            continue
        message = record.get("message") or {}
        if message.get("role") != "assistant":
            continue
        content = message.get("content")
        text = ""
        if isinstance(content, list):
            text = "".join(
                block.get("text", "") for block in content if isinstance(block, dict) and block.get("type") == "text"
            )
        elif isinstance(content, str):
            text = content
        text = text.strip()
        if text:
            found.append((record.get("timestamp") or "", text))

for index, (stamp, text) in enumerate(reversed(found[-limit:]), start=1):
    path = os.path.join(out_dir, f"{index}.md")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text.rstrip() + "\n")
    when = ""
    try:
        when = datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone().strftime("%H:%M")
    except Exception:
        pass
    print(f"{path}\t{when}\t{' '.join(text.split())[:110]}")
PY
}

if [ "$doc" = "pick" ]; then
	# One entry per message, chosen with fzf. Escape leaves without a review, which
	# is what a picker is for: no review is better than the wrong one.
	transcript=$(pick_transcript "$PWD" 2>/dev/null || true)
	if [ -z "$transcript" ]; then
		echo "plannotator-review: pi has no transcript for this folder" >&2
		exit 1
	fi
	list=$(list_messages "$transcript" "$work/msgs" 60)
	if [ -z "$list" ]; then
		echo "plannotator-review: pi has no message to review here" >&2
		exit 1
	fi
	choice=""
	if command -v fzf >/dev/null 2>&1; then
		choice=$(printf '%s\n' "$list" | fzf --delimiter='\t' --with-nth=2,3 \
			--prompt='message > ' --preview='cat {1}' --preview-window='right,60%') || true
	elif command -v sk >/dev/null 2>&1; then
		choice=$(printf '%s\n' "$list" | sk --delimiter='\t' --with-nth=2,3 --prompt='message > ') || true
	else
		# No picker on this machine, and guessing would review the wrong message.
		echo "plannotator-review: install fzf or sk to choose a message" >&2
		exit 1
	fi
	if [ -z "$choice" ]; then
		exit 0
	fi
	picked=$(printf '%s' "$choice" | cut -f1)
	docfile="$work/message"
	cp "$picked" "$docfile"
fi

if [ "$doc" = "message" ]; then
	# The transcript, not the screen: no prompt box, no status line, and no
	# lines broken where the terminal happened to wrap them. The file is named
	# `message` because Plannotator titles the review after it, and the extension
	# says nothing.
	docfile="$work/message"
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
