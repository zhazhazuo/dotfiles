#!/usr/bin/env python3
"""Score whether a run produced the exit artifact its phase demands.

Routing says which card the agent read. This says whether the work the card demands exists in
the transcript: a map, a ratified decision list, S-identifiers, a test written before the source,
a stated root cause, a pruned suite, or a named handoff.

The rubric is a presence check, frozen with the fixture. It is deliberately mechanical so a
dispute is settled by reading the code, not by re-judging the prose. `--explain` prints which
condition fired.

Usage:

    score_artifact.py --transcript T.jsonl --artifact map
    score_artifact.py --self-test
"""
import argparse
import json
import re
import sys
import tempfile

ARTIFACTS = ("map", "restate", "scenario", "testfirst", "rootcause", "prune", "handoff",
              "mock", "split", "progress")

CODE_PATH = re.compile(r"\b[\w./-]+\.(ts|tsx|js|jsx|py|go|rs|java|lua|sql|json|md|toml|sh)\b")
IDENT = re.compile(r"`([A-Za-z_][\w.$-]{2,})`")
SCENARIO_ID = re.compile(r"\bS-?\d{1,3}\b")
LIST_ITEM = re.compile(r"^\s{0,3}(?:\d+[.)]|[-*])\s+\S")
TEST_PATH = re.compile(r"(^|/)(test|tests|__tests__|spec)/|\.(test|spec)\.[a-z]+$")
RUNNER = re.compile(r"\b(node --test|vitest|jest|pytest|deno test|bun test|npm (run )?test|go test|cargo test)\b")
SOURCE_PATH = re.compile(r"\.(ts|tsx|js|jsx|py|go|rs|java|lua|sql|sh)$")
FILEISH = re.compile(r"\.[A-Za-z0-9]{1,6}$")


def read_events(path):
    out = []
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
    except OSError as exc:
        sys.exit(f"cannot read {path}: {exc}")
    for line in lines:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            out.append(json.loads(line))
        except ValueError:
            continue
    return out


def harvest(evs):
    text_parts, cmds, writes, deletes = [], [], [], []
    for o in evs:
        if o.get("type") == "message_end":
            content = (o.get("message") or {}).get("content")
            if isinstance(content, str):
                text_parts.append(content)
            elif isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        text_parts.append(block.get("text") or "")
        if o.get("type") != "tool_execution_start":
            continue
        args = o.get("args") or {}
        tool = o.get("toolName") or o.get("tool") or ""
        blob = " ".join(v for v in args.values() if isinstance(v, str))
        if tool in ("bash", "shell"):
            cmds.append(blob)
            for hit in re.findall(r"\brm\s+(-\S+\s+)*([^\s;&|]+)", blob):
                deletes.append(hit[1])
        if tool in ("write", "edit"):
            for key in ("path", "file_path", "filePath"):
                target = args.get(key)
                if isinstance(target, str) and FILEISH.search(target):
                    writes.append(target)
        if isinstance(args.get("content"), str) or isinstance(args.get("newText"), str):
            text_parts.append(args.get("content") or args.get("newText") or "")
        for change in args.get("edits") or []:
            if isinstance(change, dict) and isinstance(change.get("newText"), str):
                text_parts.append(change["newText"])
    return "\n".join(text_parts), cmds, writes, deletes


def check_map(text):
    paths = {m.group(0) for m in CODE_PATH.finditer(text)}
    symbols = set(IDENT.findall(text))
    reuse = re.search(r"\b(reuse|re-?use|already exists|extend|existing|no new)\b", text, re.I)
    paths = {m.group(0) for m in CODE_PATH.finditer(text)}
    if len(paths) >= 2 and len(symbols) >= 2 and reuse:
        return True, f"map: {len(paths)} paths, {len(symbols)} symbols, reuse stated"
    return False, f"map needs 2 paths + 2 backticked symbols + a reuse word; got {len(paths)}/{len(symbols)}/{bool(reuse)}"


def check_restate(text):
    items = [line for line in text.splitlines() if LIST_ITEM.match(line)]
    ratified = re.search(r"\b(agree|agreed|confirm|ratif|objection|object|differ)\b", text, re.I)
    if len(items) >= 2 and ratified:
        return True, f"restate: {len(items)} list items and a ratification word"
    return False, f"restate needs 2 list items + a ratification word; got {len(items)}/{bool(ratified)}"


def check_scenario(text):
    ids = set(SCENARIO_ID.findall(text))
    source = re.search(r"\b(PRD|spec|section|§|line \d+|requirement)\b", text, re.I)
    if len(ids) >= 2 and source:
        return True, f"scenario: {len(ids)} S-identifiers and a source reference"
    return False, f"scenario needs 2 S-identifiers + a source reference; got {len(ids)}/{bool(source)}"


def check_testfirst(text, cmds, writes):
    test_writes = [w for w in writes if TEST_PATH.search(w)]
    src_writes = [w for w in writes if SOURCE_PATH.search(w) and not TEST_PATH.search(w)]
    ran = [c for c in cmds if RUNNER.search(c)]
    if test_writes and src_writes and ran:
        return True, f"testfirst: test {test_writes[0]}, source {src_writes[0]}, runner ran"
    return False, ("testfirst needs a test write, a source write and a runner command; "
                   f"got {len(test_writes)}/{len(src_writes)}/{len(ran)}")


def check_rootcause(text):
    stated = re.search(r"\broot cause\b", text, re.I)
    causal = re.search(r"\b(because|since|therefore|which means|so that)\b", text, re.I)
    symbol = IDENT.search(text)
    if stated and causal and symbol:
        return True, f"rootcause: stated, causal link, symbol {symbol.group(1)}"
    # A premise that does not hold has no root cause to state. The phase's work then is the
    # evidence request, which must name what it examined and what evidence is missing.
    request = re.search(r"\b(send me|provide|share|need)\b[^.]{0,80}\b(trace|stack|log|failing run|output)\b", text, re.I)
    examined = re.search(r"`([^`]+)`|\b[\w/.-]+\.(ts|tsx|js|py|go|rs)\b", text)
    if request and examined:
        return True, "rootcause: premise disproved, evidence request names what it examined"
    return False, ("rootcause needs 'root cause' + a causal word + a symbol, or an evidence request "
                   f"that names what it examined; got {bool(stated)}/{bool(causal)}/{bool(symbol)}/"
                   f"{bool(request)}/{bool(examined)}")


def check_prune(text, cmds, writes, deletes):
    gone = [p for p in deletes if TEST_PATH.search(p)] + [w for w in writes if TEST_PATH.search(w)]
    gap = re.search(r"\b(E2E|end-to-end|integration|browser)\b", text, re.I)
    if gone and gap:
        return True, f"prune: {gone[0]} removed and the E2E gap named"
    return False, f"prune needs a removed test path + a named E2E gap; got {len(gone)}/{bool(gap)}"


def check_handoff(text):
    named = re.search(r"SKILL\.md|\b(skill|route|handoff|next step)\b", text, re.I)
    action = re.search(r"\b(read|run|open|then|next|use|call)\b", text, re.I)
    if named and action:
        return True, "handoff: a named target and a next action"
    return False, "handoff needs a named target and a next action"


def check_mock(text, writes):
    profile = [w for w in writes if re.search(r"mock|profile|fixture|stub", w, re.I)]
    cleanup = re.search(r"\b(delete|remove|ship|shipped|real endpoint)\b", text, re.I)
    if profile and cleanup:
        return True, f"mock: {profile[0]} and the deletion condition stated"
    return False, f"mock needs a profile file + a deletion condition; got {len(profile)}/{bool(cleanup)}"


def check_split(text, writes):
    screens = [w for w in writes if w.endswith((".tsx", ".jsx", ".vue"))]
    modules = [w for w in writes if w.endswith((".ts", ".js")) and not w.endswith(".d.ts")]
    hook = re.search(r"export (function|const) use[A-Z]\w*", text)
    if screens and (modules or hook):
        return True, "split: a screen edit and logic moved to a module or a hook"
    return False, f"split needs a screen edit + a module or a hook; got {len(screens)}/{len(modules)}/{bool(hook)}"


PROGRESS_HEADINGS = ["Status", "Objective", "State", "Open Questions", "Next",
                     "Decisions", "Constraints", "Assumptions", "Context"]


def check_progress_file(text, writes):
    """Check the progress index, canonical section order, status and Tier 1 character budget."""
    paths = [path.replace(chr(92), "/") for path in writes]
    has_index = any(path.endswith(".ai-artifacts/progress/INDEX.md") for path in paths)
    has_unit = any(re.search(r"\.ai-artifacts/progress/(?!INDEX\.md$)[^/]+\.md$", path)
                   for path in paths)
    if not has_index or not has_unit:
        return False, f"progress needs INDEX.md and one work-unit write; got {has_index}/{has_unit}"
    last_reason = "progress has no complete work-unit document"
    documents = re.finditer(r"(?ms)^# ([^\n]+)\n(.*?)(?=^# |\Z)", text)
    for document in documents:
        body = document.group(2)
        headings = re.findall(r"^## ([^\n]+)$", body, re.M)
        if headings != PROGRESS_HEADINGS:
            if headings:
                last_reason = "progress headings differ: " + ", ".join(headings)
            continue
        if not re.search(r"^## Status\n(active|completed|archived)\s*$", body, re.M):
            last_reason = "progress status must be active, completed or archived"
            continue
        tier_one = re.search(r"^## Status\n(.*?)^## Decisions$", body, re.M | re.S)
        if not tier_one:
            last_reason = "progress cannot isolate Tier 1"
            continue
        tier_one_chars = len(tier_one.group(1))
        if tier_one_chars > 1600:
            last_reason = f"progress Tier 1 has {tier_one_chars} chars, over 1600"
            continue
        return True, f"progress: canonical sections, Tier 1 {tier_one_chars} chars"
    return False, last_reason


def score(artifact, text, cmds, writes, deletes):
    if artifact in ("-", "", "na"):
        return "na", "no artifact expected"
    if artifact == "map":
        ok, why = check_map(text)
    elif artifact == "restate":
        ok, why = check_restate(text)
    elif artifact == "scenario":
        ok, why = check_scenario(text)
    elif artifact == "testfirst":
        ok, why = check_testfirst(text, cmds, writes)
    elif artifact == "rootcause":
        ok, why = check_rootcause(text)
    elif artifact == "prune":
        ok, why = check_prune(text, cmds, writes, deletes)
    elif artifact == "handoff":
        ok, why = check_handoff(text)
    elif artifact == "mock":
        ok, why = check_mock(text, writes)
    elif artifact == "split":
        ok, why = check_split(text, writes)
    elif artifact == "progress":
        ok, why = check_progress_file(text, writes)
    else:
        return "fail", f"unknown artifact {artifact}"
    return ("pass" if ok else "fail"), why


def self_test():
    progress_unit = """# cache-invalidation

## Status
active

## Objective
Keep cached tenant data separate.

## State
- Cache keys include the tenant.

## Open Questions
- None.

## Next
- Measure the hit rate.

## Decisions
- Key the cache by tenant.

## Constraints
- Preserve the existing API.

## Assumptions
- Every request has a tenant.

## Context
Prefix matching was rejected.
"""
    progress_index = """# Progress Index
active | cache-invalidation | main | Cache keys include tenant
"""
    progress_writes = [".ai-artifacts/progress/INDEX.md",
                       ".ai-artifacts/progress/cache-invalidation.md"]
    cases = {
        "map": (
            "The map: `src/orders.ts` holds `processOrder` and `orderWithTaxCents`. "
            "`src/session.ts` calls `processOrder`, so extend the existing `Order` type. "
            "Run `node --test`.",
            "I will rename the function.",
        ),
        "restate": (
            "The decisions I hear:\n1. Cache the invoice list for 60s.\n2. Key it by tenant id.\n"
            "Do you agree to both, or is there an objection?",
            "Here is the spec.",
        ),
        "scenario": (
            "S-1: a paid order renders the invoice. Source: PRD section 3.\n"
            "S-2: a refunded order hides it. Source: PRD section 4.",
            "Derive the tests from memory.",
        ),
        "testfirst": (None, "I wrote the test after the fix."),
        "rootcause": (
            "The root cause is `shouldRetry`: it counts attempts, not failures, because the "
            "array grows on success. The fix is to count failures.",
            "It fails sometimes. I retried it.",
        ),
        "prune": (None, "The suite is large."),
        "handoff": (
            "Read `~/.agents/skills/write-discoverable-code/SKILL.md`, then rename the symbol.",
            "Done.",
        ),
        "mock": (None, "I will mock the endpoint later."),
        "split": (None, "The component is too big."),
        "progress": (None, "The session is recorded."),
    }
    text_ev = {"type": "message_end", "message": {"role": "assistant", "content": [{"type": "text", "text": ""}]}}
    tool_ev = {"type": "tool_execution_start", "toolName": "bash", "args": {"command": ""}}
    write_ev = {"type": "tool_execution_start", "toolName": "edit", "args": {"path": "", "newText": ""}}

    def build(kind, payload):
        good, bad = payload
        if kind == "testfirst":
            return (
                [dict(text_ev, message={"role": "assistant", "content": [{"type": "text", "text": ""}]})
                 ]
                + [dict(write_ev, args={"path": "test/orders.test.ts", "newText": ""}),
                   dict(write_ev, args={"path": "src/orders.ts", "newText": ""}),
                   dict(tool_ev, args={"command": "node --test"})],
                [dict(text_ev, message={"role": "assistant", "content": [{"type": "text", "text": bad}]})],
            )
        if kind == "prune":
            return (
                [dict(text_ev, message={"role": "assistant", "content": [
                    {"type": "text", "text": "The E2E gap is closed by the browser suite."}]}),
                 dict(tool_ev, args={"command": "rm test/mocks/orders.test.ts"})],
                [dict(text_ev, message={"role": "assistant", "content": [{"type": "text", "text": bad}]})],
            )
        if kind == "mock":
            return (
                [dict(text_ev, message={"role": "assistant", "content": [
                    {"type": "text", "text": "The profile is copied from a real response and is deleted when the real endpoint ships."}]}),
                 dict(write_ev, args={"path": "web/mock/invoices.json", "newText": "{}"})],
                [dict(text_ev, message={"role": "assistant", "content": [{"type": "text", "text": bad}]})],
            )
        if kind == "split":
            return (
                [dict(text_ev, message={"role": "assistant", "content": [{"type": "text", "text": ""}]}),
                 dict(write_ev, args={"path": "web/InvoiceScreen.tsx", "newText": ""}),
                 dict(write_ev, args={"path": "web/useInvoices.ts", "newText": "export function useInvoices() {}"})],
                [dict(text_ev, message={"role": "assistant", "content": [{"type": "text", "text": bad}]})],
            )
        if kind == "progress":
            return (
                [dict(write_ev, args={"path": progress_writes[0], "content": progress_index}),
                 dict(write_ev, args={"path": progress_writes[1], "content": progress_unit})],
                [dict(text_ev, message={"role": "assistant", "content": [{"type": "text", "text": bad}]})],
            )
        return (
            [dict(text_ev, message={"role": "assistant", "content": [{"type": "text", "text": good}]})],
            [dict(text_ev, message={"role": "assistant", "content": [{"type": "text", "text": bad}]})],
        )

    for artifact, payload in cases.items():
        pass_events, fail_events = build(artifact, payload)
        with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False, encoding="utf-8") as fh:
            for ev in pass_events:
                fh.write(json.dumps(ev) + "\n")
            pass_path = fh.name
        with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False, encoding="utf-8") as fh:
            for ev in fail_events:
                fh.write(json.dumps(ev) + "\n")
            fail_path = fh.name
        try:
            got_ok, why_pass = score(artifact, *harvest(read_events(pass_path)))
            got_bad, why_fail = score(artifact, *harvest(read_events(fail_path)))
        finally:
            import os
            os.unlink(pass_path)
            os.unlink(fail_path)
        assert got_ok == "pass", f"{artifact} pass fixture scored {got_ok}: {why_pass}"
        assert got_bad == "fail", f"{artifact} fail fixture scored {got_bad}: {why_fail}"
    assert score("-", "", [], [], [])[0] == "na"
    progress_failures = {
        "wrong order": (progress_unit.replace("## Open Questions\n- None.\n\n## Next\n- Measure the hit rate.\n\n", "")
                        .replace("## Context", "## Open Questions\n- None.\n\n## Next\n- Measure the hit rate.\n\n## Context"),
                        progress_writes),
        "missing index": (progress_index + progress_unit, progress_writes[1:]),
        "extra heading": (progress_unit.replace("## Context", "## Notes\nExtra.\n\n## Context"),
                          progress_writes),
        "invalid status": (progress_unit.replace("active", "unknown", 1), progress_writes),
        "Tier 1 too large": (progress_unit.replace("## Decisions", "x" * 1601 + "\n\n## Decisions"),
                             progress_writes),
    }
    for name, (text, writes) in progress_failures.items():
        got, why = score("progress", text, [], writes, [])
        assert got == "fail", f"progress {name} failure scored {got}: {why}"
    surrounded = "# Unrelated\n\n## Notes\nIgnore this document.\n" + progress_index + progress_unit
    ok, why = score("progress", surrounded, [], progress_writes, [])
    assert ok == "pass", f"progress valid document was hidden by surrounding text: {why}"
    read_only_events = [
        {"type": "tool_execution_start", "toolName": "read",
         "args": {"path": progress_writes[0]}},
        {"type": "tool_execution_start", "toolName": "read",
         "args": {"path": progress_writes[1]}},
        {"type": "message_end", "message": {"role": "toolResult",
         "content": [{"type": "text", "text": progress_unit}]}},
    ]
    read_only_text, _, read_only_writes, _ = harvest(read_only_events)
    ok, why = score("progress", read_only_text, [], read_only_writes, [])
    assert ok == "fail", f"progress read-only session scored {ok}: {why}"
    declined = ("`test/mocks/webhook.mock.test.ts` has no timer and no clock. "
                "Send me one failing run: the test name, the assertion message, and the stack.")
    ok, why = score("rootcause", declined, [], [], [])
    assert ok == "pass", why
    ok, why = score("rootcause", "Send me the trace, please.", [], [], [])
    assert ok == "fail", why
    print(f"score_artifact self-test OK: {len(cases)} pass fixtures, {len(cases)} fail fixtures, "
          "evidence request accepted only when it names what it examined")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--transcript")
    ap.add_argument("--artifact", default="-")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--explain", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not args.transcript:
        ap.error("--transcript is required")
    verdict, why = score(args.artifact, *harvest(read_events(args.transcript)))
    if args.json:
        print(json.dumps({"artifact": args.artifact, "verdict": verdict, "reason": why}))
    elif args.explain:
        print(f"ARTIFACT {verdict}  {why}")
    else:
        print(verdict)
    return 0 if verdict in ("pass", "na") else 1


if __name__ == "__main__":
    sys.exit(main())
