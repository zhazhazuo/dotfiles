#!/usr/bin/env bash
# Capture replies for the reply-style measure.
#
# Runs one fresh pi session per prompt in evals/reply-prompts.txt, with no session
# reuse, in a scratch directory so the agent cannot explore a repository instead of
# answering. Writes <outdir>/NN.md (the reply text) and <outdir>/NN.jsonl (the raw
# event stream).
#
# Usage:
#   evals/capture-replies.sh <outdir>
#   evals/capture-replies.sh --only 7 <outdir>     # re-capture one prompt only
#
# Score afterwards with:
#   python3 evals/count-reply-defects.py /tmp/reply-baseline/*.md
set -uo pipefail

OUT=""
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only)
      [ $# -ge 2 ] || { echo "--only needs a prompt number" >&2; exit 2; }
      ONLY="$2"; shift 2 ;;
    --*) echo "unknown option: $1" >&2; exit 2 ;;
    *) OUT="$1"; shift ;;
  esac
done
[ -n "$OUT" ] || { echo "usage: capture-replies.sh [--only N] <outdir>" >&2; exit 2; }
ONLY_N=0
if [ -n "$ONLY" ]; then
  case "$ONLY" in *[!0-9]*) echo "--only needs a number" >&2; exit 2 ;; esac
  ONLY_N=$((10#$ONLY))
  [ "$ONLY_N" -ge 1 ] || { echo "--only needs a number >= 1" >&2; exit 2; }
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPTS="${ROOT}/evals/reply-prompts.txt"
[ -f "$PROMPTS" ] || { echo "prompts not found: $PROMPTS" >&2; exit 2; }

mkdir -p "$OUT"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/reply-capture.XXXXXX")"
i=0

while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  shape="${line%%|*}"
  prompt="${line#*|}"
  case "$shape" in
    prose|structure) ;;
    *) echo "bad shape '${shape}' on: ${line:0:50}" >&2; exit 2 ;;
  esac
  i=$((i + 1))
  id=$(printf '%02d' "$i")
  if [ "$ONLY_N" -gt 0 ] && [ "$i" -ne "$ONLY_N" ]; then continue; fi

  ( cd "$SCRATCH" && pi -p --no-session --mode json \
      --append-system-prompt "Answer the user's question directly. Do not modify any file." \
      "$prompt" ) > "${OUT}/${id}.jsonl" 2>&1 < /dev/null

  python3 - "${OUT}/${id}.jsonl" > "${OUT}/${id}.md" <<'PY'
import json, sys

chunks = []
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        event = json.loads(line)
    except Exception:
        continue
    if event.get("type") != "agent_end":
        continue
    for message in event.get("messages", []):
        if message.get("role") != "assistant":
            continue
        content = message.get("content")
        if isinstance(content, str):
            chunks.append(content)
        elif isinstance(content, list):
            for part in content:
                if isinstance(part, dict) and part.get("type") == "text":
                    chunks.append(part["text"])
print((chunks[-1] if chunks else "").strip())
PY

  echo "captured ${id}: $(wc -c < "${OUT}/${id}.md" | tr -d ' ') bytes  <- ${prompt:0:60}"
done < "$PROMPTS"

echo
echo "replies:    ${OUT}"
echo "score with: python3 ${ROOT}/evals/count-reply-defects.py ${OUT}/*.md"
