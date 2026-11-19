#!/usr/bin/env python3
"""Decide one loop round, and stop the loop, from the numbers alone.

Two rules do the deciding, both stated before round one:

  accept  the change only when |median(candidate) - median(baseline)| is greater than the
          spread of the 3 repeats, and no moment that passed at baseline now fails.
  stop    when a rule fires: freeze violation, cost ceiling, delta inside the spread,
          held-out pass rate flat for N rounds, or the round cap.

A stopped loop reports its best round by median, never its best single cell.

Usage:

    decide.py --baseline B.json --candidate C.json --split iterate [--json]
    decide.py --stop-state S.json [--json]
    decide.py --ledger --decision D.json --hypothesis "..." [--section ..] [--quote ..]
    decide.py --self-test
"""
import argparse
import json
import os
import random
import sys
from statistics import median


def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError) as exc:
        sys.exit(f"cannot read {path}: {exc}")


def repeat_totals(score, split):
    """Pass count per repeat across the moments of one split."""
    cells = [c for c in score["cells"] if c.get("split") == split]
    repeats = sorted({c["repeat"] for c in cells})
    totals = []
    for repeat in repeats:
        totals.append(sum(1 for c in cells if c["repeat"] == repeat and c["verdict"] == "PASS"))
    return totals


def spread(values):
    return max(values) - min(values) if values else 0


def moment_passes(score, split):
    counts = {}
    for cell in score["cells"]:
        if cell.get("split") != split:
            continue
        counts.setdefault(cell["id"], [0, 0])
        counts[cell["id"]][1] += 1
        if cell["verdict"] == "PASS":
            counts[cell["id"]][0] += 1
    return counts


def regressions(base, cand, split):
    before = moment_passes(base, split)
    after = moment_passes(cand, split)
    lost = []
    for moment_id, (passes, total) in before.items():
        if total == 0:
            continue
        if passes * 2 >= total:                     # passed by majority at baseline
            got, seen = after.get(moment_id, (0, 0))
            if seen and got * 2 <= seen:            # failed by majority now
                lost.append(f"{moment_id}:{passes}/{total}->{got}/{seen}")
    return lost


def decide(base, cand, split):
    base_totals = repeat_totals(base, split)
    cand_totals = repeat_totals(cand, split)
    base_median = median(base_totals) if base_totals else 0
    cand_median = median(cand_totals) if cand_totals else 0
    band = max(spread(base_totals), spread(cand_totals))
    delta = cand_median - base_median
    lost = regressions(base, cand, split)
    accepted = abs(delta) > band and not lost
    if lost:
        reason = "regression:" + ",".join(lost)
    elif abs(delta) <= band:
        reason = "inside-spread"
    else:
        reason = "outside-spread"
    return {
        "split": split,
        "baseline_repeats": base_totals,
        "candidate_repeats": cand_totals,
        "baseline_median": base_median,
        "candidate_median": cand_median,
        "spread": band,
        "delta": delta,
        "regressions": lost,
        "accepted": accepted,
        "reason": reason,
    }


def stop_rules(state):
    """Return every stop rule that fires, in priority order."""
    fired = []
    if state.get("freeze_violation"):
        fired.append(("freeze", state["freeze_violation"]))
    ceiling = state.get("ceiling_usd")
    spent = state.get("cost_usd", 0.0)
    tokens = state.get("tokens", 0)
    token_ceiling = state.get("ceiling_tokens")
    if ceiling and spent > ceiling:
        fired.append(("cost", f"spent ${spent:.4f} over ceiling ${ceiling:.4f}"))
    if token_ceiling and tokens > token_ceiling:
        fired.append(("cost", f"spent {tokens} tokens over ceiling {token_ceiling}"))
    if state.get("delta_inside_spread"):
        fired.append(("delta-inside-spread", "the change sits inside the repeat spread"))
    if state.get("holdout_flat_rounds", 0) >= state.get("holdout_patience", 2):
        fired.append(("holdout-flat", f"{state['holdout_flat_rounds']} rounds without held-out gain"))
    if state.get("round", 0) >= state.get("cap_rounds", 6):
        fired.append(("round-cap", f"round {state['round']} reached the cap"))
    return fired


def best_round(rounds):
    """The best round by median, ties broken by the smaller spread, then the earlier round."""
    ranked = sorted(rounds, key=lambda r: (-r["median"], r["spread"], r["round"]))
    return ranked[0] if ranked else None


def ledger_record(decision, args):
    stamp = args.ts or "1970-01-01T00:00:00Z"
    token = "".join(random.choice("0123456789abcdef") for _ in range(4))
    return {
        "id": f"fb-{stamp}-{token}",
        "ts": stamp,
        "skill": decision["skill"],
        "skill_path": decision.get("skill_path", ""),
        "inventory": os.path.expanduser("~/.agents/skills"),
        "feedback": args.hypothesis or "",
        "kind": "other",
        "where": {"section": args.section or "", "quote": args.quote or "", "status": "present"},
        "diagnosis": decision.get("measurement", ""),
        "candidate_change": args.change or "",
        "confidence": "medium",
        "questions": [],
        "duplicate_of": None,
        "status": "open",
        "loop": decision,
    }


def self_test():
    def score(passes_by_repeat, moment_ids, split="iterate"):
        cells = []
        for repeat, passes in enumerate(passes_by_repeat, start=1):
            for index, moment_id in enumerate(moment_ids):
                cells.append({"id": moment_id, "split": split, "repeat": repeat,
                              "verdict": "PASS" if index < passes else "FAIL"})
        return {"cells": cells}

    ids = ["m01", "m02", "m10", "m15", "m16"]
    base = score([3, 3, 3], ids)
    # 3/3 -> 5/3 is impossible; use 6 moments for a clean +2.
    ids6 = ids + ["m03"]
    base6 = score([3, 3, 3], ids6)
    better = score([5, 5, 4], ids6)
    verdict = decide(base6, better, "iterate")
    assert verdict["baseline_median"] == 3 and verdict["candidate_median"] == 5, verdict
    assert verdict["spread"] == 1 and verdict["delta"] == 2, verdict
    assert verdict["accepted"] and verdict["reason"] == "outside-spread", verdict

    noise = score([4, 3, 4], ids6)
    quiet = decide(base6, noise, "iterate")
    assert quiet["spread"] == 1 and abs(quiet["delta"]) <= 1, quiet
    assert not quiet["accepted"] and quiet["reason"] == "inside-spread", quiet

    lost = score([5, 5, 4], ids6)
    lost["cells"] = [dict(c) for c in lost["cells"]]
    for cell in lost["cells"]:
        if cell["id"] == "m02":
            cell["verdict"] = "FAIL"
    hurt = decide(base6, lost, "iterate")
    assert not hurt["accepted"] and hurt["reason"].startswith("regression:m02"), hurt

    flat = decide(base, base, "iterate")
    assert flat["delta"] == 0 and not flat["accepted"], flat

    assert stop_rules({"round": 1}) == []
    fired = stop_rules({"round": 1, "ceiling_usd": 0.5, "cost_usd": 0.6})
    assert fired[0][0] == "cost", fired
    fired = stop_rules({"round": 1, "ceiling_tokens": 100, "tokens": 101})
    assert fired[0][0] == "cost", fired
    fired = stop_rules({"round": 1, "delta_inside_spread": True})
    assert fired[0][0] == "delta-inside-spread", fired
    fired = stop_rules({"round": 2, "holdout_flat_rounds": 2, "holdout_patience": 2})
    assert fired[0][0] == "holdout-flat", fired
    fired = stop_rules({"round": 6, "cap_rounds": 6})
    assert fired[0][0] == "round-cap", fired
    assert stop_rules({"round": 1, "freeze_violation": "rules-routing.json"})[0][0] == "freeze"

    rounds = [{"round": 1, "median": 4, "spread": 1},
              {"round": 2, "median": 4, "spread": 0},
              {"round": 3, "median": 5, "spread": 2}]
    best = best_round(rounds)
    assert best is not None and best["round"] == 3, best
    rounds = [{"round": 1, "median": 4, "spread": 1},
              {"round": 2, "median": 4, "spread": 0}]
    best = best_round(rounds)
    assert best is not None and best["round"] == 2, best
    print("decide self-test OK: accept, inside-spread, regression, flat, five stop rules, best round")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline")
    ap.add_argument("--candidate")
    ap.add_argument("--split", default="iterate")
    ap.add_argument("--stop-state")
    ap.add_argument("--ledger", action="store_true")
    ap.add_argument("--decision")
    ap.add_argument("--hypothesis")
    ap.add_argument("--section")
    ap.add_argument("--quote")
    ap.add_argument("--change")
    ap.add_argument("--ts")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        self_test()
        return 0

    if args.stop_state:
        state = load(args.stop_state)
        fired = stop_rules(state)
        if args.json:
            print(json.dumps({"fired": fired, "stop": bool(fired)}))
        else:
            print("STOP " + fired[0][0] + "  " + fired[0][1] if fired else "CONTINUE")
        return 0

    if args.ledger:
        decision = load(args.decision)
        record = ledger_record(decision, args)
        path = os.path.expanduser("~/.agents/skill-feedback/records.jsonl")
        try:
            with open(path, "a", encoding="utf-8") as fh:
                fh.write(json.dumps(record, sort_keys=True) + "\n")
        except OSError as exc:
            sys.exit(f"cannot append to {path}: {exc}")
        print(record["id"])
        return 0

    if not args.baseline or not args.candidate:
        ap.error("--baseline and --candidate are required")
    result = decide(load(args.baseline), load(args.candidate), args.split)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"split={result['split']} baseline={result['baseline_repeats']} "
              f"candidate={result['candidate_repeats']} spread={result['spread']} "
              f"delta={result['delta']} -> {'ACCEPT' if result['accepted'] else 'REJECT'} "
              f"({result['reason']})")
    return 0 if result["accepted"] else 1


if __name__ == "__main__":
    sys.exit(main())
