#!/usr/bin/env bash
#
# plannotator-review — review a document in Plannotator and paste the new
# annotations into an agent's prompt.
#
# The Herdr plugin hands the feedback to a pane through `--deliver-to`, a
# Herdr-only channel, and it reviews an agent reply by opening Plannotator's own
# picker: `plannotator-tui herdr last`. Rex has no plugin channel, so the same
# flow is built here from two pieces: Plannotator records every review it ends
# with annotations, and this script reads that record and pastes it into the
# target block as one paste event. A paste, not typed keys: a newline delivered
# as a key would submit the agent's prompt instead of adding a line to it.
#
# Usage:
#   plannotator-review.sh <document|folder|-|message|pick> <session_id> <target_block_id>
#
# `-` reviews the target pane's text, for a pane that has no transcript.
# `folder` reviews the pane's folder with Plannotator's file tree, which is what
# the Herdr plugin's `prefix+shift+o` does.
# `message` reviews the last message pi wrote, with no picker.
# `pick` opens Plannotator's picker over pi's recent replies, which is what the
# Herdr plugin does, and reviews the one chosen.
#
# The picked review keeps its annotations inside Plannotator, so they are read
# back from the record it writes when a review ends: no second export, and the
# text is the same text the review offers to copy as feedback.
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

# The review sits in a floating layer with the focus, and closing that layer
# leaves the focus on whichever pane Rex picks, not on the one being reviewed.
# Focus is put back on the reviewed pane here, while the layer is still open, so
# the close leaves it alone: a closing block that does not hold the focus does
# not move it.
focus_reviewed_pane() {
	command -v rex >/dev/null 2>&1 || return 0
	rex api call session.focus_block \
		"$(jq -nc --arg s "$session" --arg b "$target" '{session_id: $s, block_id: $b}')" \
		>/dev/null 2>&1 || true
	# Give the focus change a moment to land before this block goes away.
	sleep 0.15
}

cleanup() {
	focus_reviewed_pane
	rm -rf "$work"
}
trap cleanup EXIT

# Where Plannotator keeps its reviews. `PLANNOTATOR_DATA_DIR` moves it, which is
# what the tests use.
data_dir=${PLANNOTATOR_DATA_DIR:-$HOME/.plannotator}

# An ISO 8601 stamp with milliseconds and a Z, the shape the records carry.
stamp_now() {
	python3 -c '
import datetime
now = datetime.datetime.now(datetime.timezone.utc)
print(now.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (now.microsecond // 1000))
'
}

# The newest review record written after a stamp, as one JSON line. Every project
# keeps its own index, so all of them are read.
record_since() {
	local since="$1"
	ls -t "$data_dir"/feedback/*/index.jsonl 2>/dev/null | while read -r index; do
		jq -r --arg since "$since" \
			'select((.decision // "") == "feedback" and (.ts // "") > $since) | "\(.ts)\t\(tojson)"' \
			"$index" 2>/dev/null || true
	done | sort | tail -1 | cut -f2-
}

# Pastes a review's feedback into the prompt of the block being reviewed.
deliver() {
	local feedback="$1"
	[ -s "$feedback" ] || return 0

	printf 'Review feedback from Plannotator:\n\n%s\n' "$(cat "$feedback")" >"$work/paste.md"

	local payload
	payload=$(jq -nc --arg s "$session" --arg b "$target" --rawfile t "$work/paste.md" \
		'{session_id: $s, block_id: $b, event: {type: "paste", payload: {text: $t}}}')
	if ! rex api call block.event "$payload" >/dev/null 2>&1; then
		echo "plannotator-review: could not paste the annotations into $target" >&2
		exit 1
	fi

	local count
	count=$(grep -c '^## Annotation' "$feedback" || true)
	printf 'Pasted %s annotation(s) into the prompt. Press Return to send.\n' "${count:-1}"
}

# Reviews a document and delivers only the annotations this run added, because
# the export also holds every annotation the document already had.
review_document() {
	local document="$1"
	if [ ! -e "$document" ]; then
		echo "plannotator-review: no such document: $document" >&2
		exit 1
	fi

	"$tui" --export "$document" >"$work/before.md" 2>/dev/null || true
	"$tui" "$document" || true
	"$tui" --export "$document" >"$work/after.md" 2>/dev/null || true

	# Any annotation the export did not already hold belongs to this run. The
	# export names the file above each set, because a folder review annotates
	# several files and each of them counts its annotations from one.
	awk '
		NR == FNR {
			if ($0 ~ /^# Annotations on /) { file = $0; next }
			if ($0 ~ /^## Annotation [0-9]+/) { held[file SUBSEP $3] = 1 }
			next
		}
		/^# Annotations on / { file = $0 }
		/^## Annotation [0-9]+/ { keep = !((file SUBSEP $3) in held) }
		keep { print }
	' "$work/before.md" "$work/after.md" >"$work/added.md"

	deliver "$work/added.md"
}

# The transcript of the pi session in this pane.
#
# The folder is not enough. Two pi panes can run in one folder, and the tool's own
# lookup then takes one of them, so a review of one pane reads the other pane's
# replies. The pane's screen tells them apart: the lines still visible there are the
# tail of that pane's own last reply, so each candidate transcript is scored by how
# many of those lines its last message holds. A screen with no match falls back to
# the newest transcript in the folder, which is what the tool would have used.
pane_transcript() {
	local cwd="$1" session="$2" block="$3"
	python3 - "$cwd" "$session" "$block" <<'PY'
import json, os, re, subprocess, sys

cwd, session, block = sys.argv[1], sys.argv[2], sys.argv[3]
root = os.environ.get("PLANNOTATOR_PI_SESSIONS") or os.path.expanduser("~/.pi/agent/sessions")


def normalise(text):
    return re.sub(r"\s+", " ", text).strip().lower()


def header_cwd(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return json.loads(handle.readline()).get("cwd")
    except Exception:
        return None


def last_message(path):
    text = ""
    with open(path, encoding="utf-8", errors="replace") as handle:
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
            if isinstance(content, list):
                piece = "".join(
                    item.get("text", "") for item in content if isinstance(item, dict) and item.get("type") == "text"
                )
            else:
                piece = content if isinstance(content, str) else ""
            if piece.strip():
                text = piece
    return text


files = []
for folder in sorted(os.listdir(root)) if os.path.isdir(root) else []:
    directory = os.path.join(root, folder)
    if not os.path.isdir(directory):
        continue
    files += [os.path.join(directory, name) for name in sorted(os.listdir(directory)) if name.endswith(".jsonl")]

candidates = [path for path in files if header_cwd(path) == cwd]
if not candidates:
    sys.exit(4)

try:
    captured = subprocess.run(
        ["rex", "capture", "-s", session, "-b", block], capture_output=True, text=True, timeout=10
    ).stdout
except Exception:
    captured = ""

visible = [normalise(line) for line in captured.splitlines()]
visible = [line for line in visible if len(line) >= 30]

best_path, best_score = None, 0
for path in candidates:
    message = normalise(last_message(path))
    score = sum(1 for line in visible if line in message) if message else 0
    if score > best_score:
        best_path, best_score = path, score

print(best_path or max(candidates, key=os.path.getmtime))
PY
}

case "$doc" in
message)
	# The transcript, not the screen: no prompt box, no status line, and no
	# lines broken where the terminal happened to wrap them. The file is named
	# `message` because Plannotator titles the review after it, and the extension
	# says nothing.
	transcript=$(pane_transcript "$PWD" "$session" "$target" 2>/dev/null || true)
	# bash 3.2, the system bash, errors on an empty array under `set -u`, so the
	# two shapes are written out rather than passed through one.
	if [ -n "$transcript" ]; then
		"$tui" last --host pi --session "$transcript" --print >"$work/message" 2>/dev/null || true
	else
		"$tui" last --host pi --print >"$work/message" 2>/dev/null || true
	fi
	if [ ! -s "$work/message" ]; then
		echo "plannotator-review: pi has no message to review here" >&2
		exit 1
	fi
	review_document "$work/message"
	;;
pick)
	# Plannotator's own picker over pi's replies, then its review of the chosen
	# one. Escape leaves without a review, and a review with no annotation writes
	# no record, so both end here with nothing pasted.
	transcript=$(pane_transcript "$PWD" "$session" "$target" 2>/dev/null || true)
	started=$(stamp_now)
	if [ -n "$transcript" ]; then
		"$tui" last --host pi --session "$transcript" || true
	else
		"$tui" last --host pi || true
	fi

	record=$(record_since "$started")
	if [ -z "$record" ]; then
		exit 0
	fi
	printf '%s' "$record" | jq -r '.feedback // ""' >"$work/feedback.md"
	deliver "$work/feedback.md"
	;;
folder)
	# The pane's folder, with the file tree herdr open shows. A folder review
	# annotates whichever files are opened, and the export names each of them.
	review_document "$PWD"
	;;
-)
	# A pane with no transcript: its screen is all there is.
	if command -v rex >/dev/null 2>&1; then
		{
			printf '# Pane text: %s\n\n' "$(basename "$PWD")"
			rex capture -s "$session" -b "$target" 2>/dev/null || true
		} >"$work/pane.md"
	else
		printf '# Pane text\n\n' >"$work/pane.md"
	fi
	review_document "$work/pane.md"
	;;
*)
	review_document "$doc"
	;;
esac
