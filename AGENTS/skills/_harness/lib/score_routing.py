#!/usr/bin/env python3
"""Score routing transcripts against a frozen fixture.

The rule sets live in the skill's `evals/rules-routing.json`, never in this file. A loop
freezes the hash of that file and of the fixture, so a rule change is visible as a freeze
violation instead of a quiet improvement.

Rules file:

    {
      "skill": "dev-nav",
      "deck_skill_name": "dev-nav",
      "own_skills":   [...],     # every skill this navigator routes to
      "orient_skills":[...],     # legal before the phase under test
      "delivery_skills":[...],   # legal after the phase under test
      "phases": {"1": ["ripwire-router"], ...}   # empty for a flat table deck
    }

Fixture columns (tab separated):

    id  moment  expected_phase  expected_skill  natural_ok  note  split  artifact

Usage:

    score_routing.py --rules R --fixture F --transcripts DIR [--repeats 3] [--json]
    score_routing.py --rules R --id m01 --expected-skill X --phase 4 T.jsonl
    score_routing.py --self-test

Every verdict carries three numbers taken from the transcript, never from judgement:
skill files read, wall seconds, and usage.cost.total (plus token counts for a provider
that reports no price).
"""
import argparse
import json
import os
import re
import sys
import tempfile

READ_VERB = re.compile(r"\b(cat|bat|less|more|head|tail|sed|rg|grep)\b")
SKILL_PATH = re.compile(r"([A-Za-z0-9_.-]+)/SKILL\.md")


# ---------------------------------------------------------------- transcript

def read_lines(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.readlines()
    except OSError as exc:
        sys.exit(f"cannot read {path}: {exc}")


def events(path):
    out = []
    for line in read_lines(path):
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            out.append(json.loads(line))
        except ValueError:
            continue
    return out


def _iso_ms(stamp):
    # 2026-11-19T04:27:01.849Z
    try:
        from datetime import datetime
        return int(datetime.fromisoformat(stamp.replace("Z", "+00:00")).timestamp() * 1000)
    except Exception:
        return None


def skill_reads(evs, exempt):
    """Every skill file the agent read, in order, first occurrence, as the skill directory name.

    A `read` tool call counts. A shell command counts only when it opens the file, so a
    `wc -l a/SKILL.md b/SKILL.md` does not turn into two reads.
    """
    seen = []
    for o in evs:
        if o.get("type") != "tool_execution_start":
            continue
        tool = o.get("toolName") or ""
        args = o.get("args") or {}
        if tool in ("read", "write", "edit"):
            blob = json.dumps(args)
        else:
            command = args.get("command") if isinstance(args, dict) else None
            if not isinstance(command, str) or not READ_VERB.search(command):
                continue
            blob = command
        for name in SKILL_PATH.findall(blob.replace("\\/", "/")):
            if name in exempt or name in seen:
                continue
            seen.append(name)
    return seen


def metrics(evs):
    cost = 0.0
    tin = tout = tcache = tcachew = ttotal = 0
    stamps = []
    for o in evs:
        if o.get("type") == "session":
            ms = _iso_ms(o.get("timestamp") or "")
            if ms:
                stamps.append(ms)
        msg = o.get("message") or {}
        ms = msg.get("timestamp")
        if isinstance(ms, int):
            stamps.append(ms)
        if o.get("type") == "message_end" and msg.get("role") == "assistant":
            usage = msg.get("usage") or {}
            cost += float((usage.get("cost") or {}).get("total") or 0)
            tin += int(usage.get("input") or 0)
            tout += int(usage.get("output") or 0)
            tcache += int(usage.get("cacheRead") or 0)
            tcachew += int(usage.get("cacheWrite") or 0)
            ttotal += int(usage.get("totalTokens") or 0)
    wall = round((max(stamps) - min(stamps)) / 1000.0, 1) if len(stamps) > 1 else 0.0
    return {
        "wall_seconds": wall,
        "cost_usd": round(cost, 6),
        "tokens_in": tin,
        "tokens_out": tout,
        "tokens_cache_read": tcache,
        "tokens_cache_write": tcachew,
        "tokens_total": ttotal or (tin + tout + tcache),
        "tokens_billable": tin + tout + tcachew,
    }


# ---------------------------------------------------------------- verdict

def verdict(reads, expected_skill, expected_phase, rules):
    own = set(rules.get("own_skills") or [])
    orient = set(rules.get("orient_skills") or [])
    delivery = set(rules.get("delivery_skills") or [])
    phases = rules.get("phases") or {}
    by_phase = {}
    for key, names in phases.items():
        for name in names:
            by_phase[name] = int(key)

    if expected_skill == "-":
        hit = [s for s in reads if s in own]
        return (not hit), ("abstained" if not hit else "forced:" + ",".join(hit))

    if expected_skill not in reads:
        return False, "expected-not-read"

    if not phases:
        bad = [s for s in reads if s in own and s not in (expected_skill, delivery)]
        bad = [s for s in bad if s not in orient]
        return (not bad), ("flat-ok" if not bad else "wrong-skill:" + ",".join(bad))

    entry = None
    for name in reads:
        if name not in by_phase:
            continue
        if name in orient and name != expected_skill:
            continue
        entry = name
        break
    if entry is None:
        return True, "entry-open"
    if by_phase[entry] != int(expected_phase):
        return False, "wrong-entry:" + entry
    return True, "entry-ok"


def score_one(path, expected_skill, expected_phase, rules):
    evs = events(path)
    reads = skill_reads(evs, set(rules.get("exempt_skill_names") or []))
    ok, code = verdict(reads, expected_skill, expected_phase, rules)
    row = {
        "verdict": "PASS" if ok else "FAIL",
        "code": code,
        "reads": reads,
        "skill_files_read": len(reads),
    }
    row.update(metrics(evs))
    return row


# ---------------------------------------------------------------- fixtures

def read_fixture(path):
    rows = []
    if True:
        for line in read_lines(path):
            line = line.rstrip("\n")
            if not line or line.lstrip().startswith("#"):
                continue
            cols = line.split("\t")
            while len(cols) < 8:
                cols.append("")
            rows.append({
                "id": cols[0].strip(),
                "moment": cols[1],
                "phase": cols[2].strip(),
                "skill": cols[3].strip(),
                "natural_ok": cols[4].strip(),
                "note": cols[5],
                "split": cols[6].strip() or "iterate",
                "artifact": cols[7].strip() or "-",
            })
    return rows


def split_of(row, want):
    if want in ("all", ""):
        return True
    return row["split"] == want


def cell_path(directory, moment_id, repeat):
    return os.path.join(directory, f"{moment_id}-r{repeat}.jsonl")


# ---------------------------------------------------------------- self-test

PASS_EVENTS = [
    {"type": "session", "timestamp": "2026-01-01T00:00:00.000Z"},
    {"type": "tool_execution_start", "toolName": "read", "args": {"path": "~/.agents/skills/write-discoverable-code/SKILL.md"}},
    {"type": "message_end", "message": {"role": "assistant", "timestamp": 1767225600000,
                                        "usage": {"input": 100, "output": 10, "cacheRead": 900,
                                                  "totalTokens": 1010, "cost": {"total": 0.002}}}},
    {"type": "message_end", "message": {"role": "assistant", "timestamp": 1767225602000,
                                        "usage": {"input": 50, "output": 5, "cacheRead": 0,
                                                  "totalTokens": 55, "cost": {"total": 0.001}}}},
]

FAIL_EVENTS = [
    {"type": "session", "timestamp": "2026-01-01T00:00:00.000Z"},
    {"type": "tool_execution_start", "toolName": "read", "args": {"path": "~/.agents/skills/structuring-ui-components/SKILL.md"}},
    {"type": "message_end", "message": {"role": "assistant", "timestamp": 1767225601000,
                                        "usage": {"input": 1, "output": 1, "totalTokens": 2}}},
]

WC_EVENTS = [
    {"type": "session", "timestamp": "2026-01-01T00:00:00.000Z"},
    {"type": "tool_execution_start", "toolName": "bash",
     "args": {"command": "wc -l write-discoverable-code/SKILL.md api-mock/SKILL.md"}},
]

NEGATIVE_EVENTS = [
    {"type": "session", "timestamp": "2026-01-01T00:00:00.000Z"},
    {"type": "tool_execution_start", "toolName": "read", "args": {"path": "~/.agents/skills/ops-nav/SKILL.md"}},
]

CONTROL_FAIL_EVENTS = [
    {"type": "session", "timestamp": "2026-01-01T00:00:00.000Z"},
    {"type": "tool_execution_start", "toolName": "read", "args": {"path": "~/.agents/skills/alignment-quiz/SKILL.md"}},
]

ENTER_WRONG_EVENTS = [
    {"type": "session", "timestamp": "2026-01-01T00:00:00.000Z"},
    {"type": "tool_execution_start", "toolName": "read", "args": {"path": "~/.agents/skills/prune-low-signal-tests/SKILL.md"}},
    {"type": "tool_execution_start", "toolName": "read", "args": {"path": "~/.agents/skills/write-discoverable-code/SKILL.md"}},
]

ORIENT_FIRST_EVENTS = [
    {"type": "session", "timestamp": "2026-01-01T00:00:00.000Z"},
    {"type": "tool_execution_start", "toolName": "read", "args": {"path": "~/.agents/skills/ripwire-router/SKILL.md"}},
    {"type": "tool_execution_start", "toolName": "read", "args": {"path": "~/.agents/skills/write-discoverable-code/SKILL.md"}},
]


def _write_tmp(events_list):
    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False, encoding="utf-8") as handle:
        for ev in events_list:
            handle.write(json.dumps(ev) + "\n")
        return handle.name


def self_test():
    rules = {
        "skill": "dev-nav",
        "deck_skill_name": "dev-nav",
        "own_skills": ["ripwire-router", "alignment-quiz", "write-discoverable-code",
                       "structuring-ui-components", "ripwire-find-bug", "prune-low-signal-tests"],
        "orient_skills": ["ripwire-router"],
        "delivery_skills": ["dev-flow-nav", "subagent-delegation"],
        "phases": {"1": ["ripwire-router"], "2": ["alignment-quiz"],
                   "4": ["write-discoverable-code", "structuring-ui-components"],
                   "5": ["ripwire-find-bug"], "6": ["prune-low-signal-tests"]},
        "exempt_skill_names": ["dev-nav"],
    }
    paths = {name: _write_tmp(evs) for name, evs in {
        "pass": PASS_EVENTS, "fail": FAIL_EVENTS, "negative": NEGATIVE_EVENTS,
        "control_fail": CONTROL_FAIL_EVENTS, "enter_wrong": ENTER_WRONG_EVENTS,
        "orient_first": ORIENT_FIRST_EVENTS, "wc": WC_EVENTS,
    }.items()}
    try:
        ok = score_one(paths["pass"], "write-discoverable-code", "4", rules)
        assert ok["verdict"] == "PASS", ok
        assert ok["reads"] == ["write-discoverable-code"], ok
        assert ok["skill_files_read"] == 1, ok
        assert ok["cost_usd"] == 0.003, ok
        assert ok["tokens_in"] == 150 and ok["tokens_out"] == 15, ok
        assert ok["tokens_cache_read"] == 900, ok
        assert ok["tokens_billable"] == 165, ok
        assert ok["wall_seconds"] == 2.0, ok

        bad = score_one(paths["fail"], "write-discoverable-code", "4", rules)
        assert bad["verdict"] == "FAIL", bad
        assert bad["code"] == "expected-not-read", bad

        neg = score_one(paths["negative"], "-", "-", rules)
        assert neg["verdict"] == "PASS" and neg["code"] == "abstained", neg

        forced = score_one(paths["control_fail"], "-", "-", rules)
        assert forced["verdict"] == "FAIL" and forced["code"].startswith("forced:"), forced

        wrong = score_one(paths["enter_wrong"], "write-discoverable-code", "4", rules)
        assert wrong["verdict"] == "FAIL" and wrong["code"].startswith("wrong-entry:"), wrong

        # Orienting before the phase is legal: the frozen rule must keep it a pass.
        oriented = score_one(paths["orient_first"], "write-discoverable-code", "4", rules)
        assert oriented["verdict"] == "PASS" and oriented["code"] == "entry-ok", oriented

        # A flat deck has no phases: the expected skill must be read and no other own skill may be.
        flat = dict(rules, phases={})
        assert score_one(paths["pass"], "write-discoverable-code", "-", flat)["verdict"] == "PASS"
        assert score_one(paths["fail"], "write-discoverable-code", "-", flat)["verdict"] == "FAIL"
        assert score_one(paths["enter_wrong"], "write-discoverable-code", "-", flat)["verdict"] == "FAIL"
        assert score_one(paths["orient_first"], "write-discoverable-code", "-", flat)["verdict"] == "PASS"

        # A command that names two skill files without opening them is not two reads.
        assert score_one(paths["wc"], "write-discoverable-code", "4", rules)["reads"] == []

        # The extractor must not count the deck under test as a skill it routes to.
        assert score_one(paths["pass"], "write-discoverable-code", "4",
                         dict(rules, exempt_skill_names=[]))["reads"] == ["write-discoverable-code"]
    finally:
        for path in paths.values():
            os.unlink(path)
    print("score_routing self-test OK: pass, miss, abstain, forced, wrong-entry, flat, metrics")


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rules")
    ap.add_argument("--fixture")
    ap.add_argument("--transcripts")
    ap.add_argument("--repeats", type=int, default=3)
    ap.add_argument("--split", default="all")
    ap.add_argument("--id")
    ap.add_argument("--expected-skill", default=None)
    ap.add_argument("--phase", default=None)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--transcript", dest="transcript_flag")
    ap.add_argument("transcript", nargs="?")
    args = ap.parse_args()
    transcript = args.transcript or args.transcript_flag

    if args.self_test:
        self_test()
        return 0

    if not args.rules:
        ap.error("--rules is required")
    try:
        with open(args.rules, encoding="utf-8") as fh:
            rules = json.load(fh)
    except (OSError, ValueError) as exc:
        sys.exit(f"cannot read rules {args.rules}: {exc}")

    if transcript:
        row = score_one(transcript, args.expected_skill, args.phase, rules)
        if args.json:
            print(json.dumps(row, sort_keys=True))
        else:
            print(f"{','.join(row['reads']) or 'NONE'}\t{row['verdict']}")
        return 0 if row["verdict"] == "PASS" else 1

    if not args.fixture or not args.transcripts:
        ap.error("batch mode needs --fixture and --transcripts")

    rows = read_fixture(args.fixture)
    out = []
    for row in rows:
        if not split_of(row, args.split):
            continue
        for repeat in range(1, args.repeats + 1):
            path = cell_path(args.transcripts, row["id"], repeat)
            cell = {"id": row["id"], "split": row["split"], "repeat": repeat,
                    "phase": row["phase"], "expected": row["skill"]}
            if not os.path.exists(path):
                cell.update({"verdict": "MISSING", "code": "no-transcript", "reads": [],
                             "skill_files_read": 0, "wall_seconds": 0.0, "cost_usd": 0.0,
                             "tokens_in": 0, "tokens_out": 0, "tokens_cache_read": 0,
                             "tokens_cache_write": 0, "tokens_total": 0,
                             "tokens_billable": 0})
            else:
                cell.update(score_one(path, row["skill"], row["phase"], rules))
            out.append(cell)

    if args.json:
        print(json.dumps(out, indent=2))
        return 0

    by_id = {}
    for cell in out:
        by_id.setdefault(cell["id"], []).append(cell)
    print("id\tsplit\treads\tverdicts\tpass/3\twall_s\tcost_usd\ttokens")
    for moment_id, cells in by_id.items():
        reads = cells[0]["reads"]
        verdicts = ",".join(c["verdict"][0] for c in cells)
        passes = sum(1 for c in cells if c["verdict"] == "PASS")
        wall = sum(c["wall_seconds"] for c in cells) / len(cells)
        cost = sum(c["cost_usd"] for c in cells)
        tokens = sum(c["tokens_total"] for c in cells)
        read_text = ",".join(reads) or "NONE"
        print(f"{moment_id}\t{cells[0]['split']}\t{read_text}\t{verdicts}\t"
              f"{passes}/{len(cells)}\t{wall:.1f}\t{cost:.6f}\t{tokens}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
