#!/usr/bin/env python3
"""Measure how often an agent updates its rpiv-todo list, from session files.

Reads the `rpiv-todo-state` custom entries that @juicesharp/rpiv-todo appends on
every state change, and the tool results around them, then reports:

  tools       tool calls in the session
  snaps       todo state changes
  maxgap      largest stretch of tool calls between two todo changes
  tail        tool calls after the last change (a run that ended without closing)
  ip/pend     tasks still in_progress / pending in the last snapshot

Usage:
  todo-cadence.py [SESSION_DIR] [--since YYYY-MM-DD] [--verbose]

Defaults to ~/.pi/agent/sessions. Exit code is 0; read the summary line as the
measure. Lower maxgap is better: the panel was truer while the agent worked.
"""

import glob
import json
import os
import statistics
import sys

SNAP_TYPE = "rpiv-todo-state"


def session_rows(path):
    snaps = []
    tools = 0
    gap = 0
    max_gap = 0
    tail = 0
    in_gap = False
    try:
        with open(path, encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                kind = entry.get("type")
                if kind == "custom" and entry.get("customType") == SNAP_TYPE:
                    snaps.append(entry.get("data") or {})
                    max_gap = max(max_gap, gap)
                    gap = 0
                    in_gap = True
                    continue
                if kind != "message":
                    continue
                message = entry.get("message") or {}
                if message.get("role") != "toolResult":
                    continue
                tools += 1
                if in_gap:
                    gap += 1
                    tail = gap
    except OSError as error:
        print(f"skip {path}: {error}", file=sys.stderr)
        return None
    if not snaps:
        return None
    last = snaps[-1]
    tasks = last.get("tasks") or []
    status = {}
    for task in tasks:
        name = task.get("status")
        status[name] = status.get(name, 0) + 1
    return {
        "path": path,
        "name": os.path.basename(path)[:19],
        "tools": tools,
        "snaps": len(snaps),
        "maxgap": max_gap,
        "tail": tail,
        "ip": status.get("in_progress", 0),
        "pend": status.get("pending", 0),
        "done": status.get("completed", 0),
    }


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    verbose = "--verbose" in argv
    since = None
    if "--since" in argv:
        since = argv[argv.index("--since") + 1]
    root = os.path.expanduser(args[0]) if args else os.path.expanduser("~/.pi/agent/sessions")

    rows = []
    for path in glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True):
        if since:
            stamp = os.path.basename(path)[:10]
            if stamp < since:
                continue
        row = session_rows(path)
        if row:
            rows.append(row)

    if not rows:
        print("no sessions with todo snapshots under " + root)
        return 0

    rows.sort(key=lambda r: -r["tools"])
    if verbose:
        header = f"{'session':20} {'tools':>6} {'snaps':>6} {'maxgap':>7} {'tail':>5} {'ip':>3} {'pend':>5} {'done':>5}"
        print(header)
        for row in rows:
            print(
                f"{row['name']:20} {row['tools']:6} {row['snaps']:6} "
                f"{row['maxgap']:7} {row['tail']:5} {row['ip']:3} {row['pend']:5} {row['done']:5}"
            )
        print()

    gaps = [r["maxgap"] for r in rows]
    sorted_gaps = sorted(gaps)
    p90 = sorted_gaps[int(len(sorted_gaps) * 0.9) - 1] if len(sorted_gaps) > 1 else sorted_gaps[0]
    dirty = sum(1 for r in rows if r["ip"] or r["pend"])
    print(
        f"{len(rows)} sessions | median maxgap {statistics.median(gaps):.0f} | "
        f"p90 {p90} | max {max(gaps)} | "
        f"ended dirty {dirty}/{len(rows)} | median tools {statistics.median([r['tools'] for r in rows]):.0f}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
