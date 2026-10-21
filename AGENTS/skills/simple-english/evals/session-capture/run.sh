#!/usr/bin/env bash
# Run N review sessions over the fixture with the AGENTS.md variant currently in place.
# usage: run.sh <outdir> <count>
set -uo pipefail
OUT="$1"; N="${2:-3}"
mkdir -p "$OUT"
PROMPT="Review plan.md and the code in this directory. Report to the lead engineer what stands between this change and a safe release."
for i in $(seq 1 "$N"); do
  id=$(printf '%02d' "$i")
  ( cd "$(cd "$(dirname "$0")" && pwd)/fixture" && pi -p --no-session --mode json \
      --append-system-prompt "Do not modify any file. Read files and inspect the code. Do not run network commands." \
      "$PROMPT" ) > "${OUT}/${id}.jsonl" 2>&1 < /dev/null
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
  echo "run ${id}: $(wc -c < "${OUT}/${id}.md" | tr -d ' ') bytes"
done
