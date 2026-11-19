---
name: iterate-skill
description: >
  Use when a skill must be improved on evidence rather than on judgement, or when a skill change
  needs a before-and-after number. Runs one iteration round against a frozen fixture: a blind
  tester measures, one edit lands, a re-run decides against the repeat spread. Covers the split
  into iterate, holdout and sealed moments, the cost and round ceilings, and the ledger entry that
  records the hypothesis, the measurement and the verdict.
disable-model-invocation: true
---

# Skill iteration loop

Expand `~` to the home directory.

Measure the skill before the change and after it. The steps and the thresholds are in
`~/.agents/skills/_harness/PROCEDURE.md`. Read that file before the first round of a new skill.
This page is the trigger and the order of work.

## Facts

- Engine: `~/.agents/skills/_harness/bin/skill-loop.sh`.
- Per-skill entry point: `<skill>/evals/loop.sh`, four lines.
- Fixture: `<skill>/evals/routing-moments.tsv`, split by its 7th column into `iterate`, `holdout`
  and `sealed`.
- Rule sets: `<skill>/evals/rules-routing.json`. Never inside the scorer.
- Frozen measurement: `<skill>/evals/freeze.json`. Thresholds: `<skill>/evals/loop-config.json`.
- Run output: `~/.agents/eval-runs/<skill>/<label>/` — transcripts, `report.tsv`, `score.json`.

## Order of work

1. Run `<skill>/evals/loop.sh --self-test` and `--check`. A scorer that fails its own fixtures
   cannot report progress.
2. `--freeze` once the fixture, the rules and the thresholds are final. Record the calibration
   round's spend first, and set the ceiling from it.
3. One round is three steps. A blind tester at an independent root path runs the fixture and
   returns `report.tsv` verbatim. An editor changes one thing in the deck. A re-run decides.
   Two agents per iteration, never one.
4. `--decide --baseline <label> --candidate <label>` with the hypothesis, the section and the
   change. It accepts only when the median moves by more than the repeat spread and no moment that
   passed at baseline now fails, and it appends the ledger entry.
5. `--stop` after every round. Name the rule that fired.

## Rules that keep the measurement honest

- The fixture, the rule sets and the instrument are frozen. `--verify` exits 3 when one moves.
  `--refreeze` is legal only before round one, and the reason goes in `RESULTS.md`.
- The deck is not frozen, because the loop exists to change it. Its hash keys the run cache.
- Do not edit the engine while a run is in flight. Bash reads a script incrementally, so the run
  dies on a syntax error and leaves transcripts it cannot score.
- A rejected change is reverted. A loop that keeps a rejected edit has no baseline.
- The holdout decides when to stop. The sealed split runs once, on the final deck, and proves the
  result. Report the best round by median, never the best cell.
- The exit-artifact score is reported beside routing, never folded into it.

## Not this skill

- Writing or revising the skill's prose: `author-high-quality-skills`.
- Installing a new capability and routing it: `integrate-capability`.
- Recording one piece of feedback about a skill: the `refiner` agent type, which may not edit it.
