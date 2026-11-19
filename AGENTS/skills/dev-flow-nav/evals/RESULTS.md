# dev-flow-nav routing eval — results

Bootstrapped on 2026-11-19 from the shared harness at `~/.agents/skills/_harness/`. No round has
run against this deck. This file records the measurement, not a verdict.

## What is frozen

`evals/freeze.json` holds sha256 of `routing-moments.tsv`, `rules-routing.json`, the fixture tree,
and the four instrument files. `./evals/loop.sh --verify` exits 3 when one moves. `loop-config.json`
holds the thresholds.

## The split

3 iterate (f01-f03), 2 holdout (f04-f05), 2 sealed (f06-f07).

## Thresholds

Set from the dev-nav calibration, because the same provider and the same instrument produce the
spend: 3 repeats per cell, 3M billable tokens for the whole loop, 6 rounds, 2 rounds of patience on
the held-out rate. A change is accepted only when the median moves by more than the repeat spread
and no moment that passed at baseline now fails.

## Calibration, run 2026-11-19

`cal` on the iterate split, 9 cells, 3 repeats, 3 jobs:

| id | expected | verdicts | artifact | reads |
|---|---|---|---|---|
| f01 | subagent-driven-development | F,F,F | P,P,P | subagent-delegation |
| f02 | subagent-delegation | P,F,F | P,P,P | subagent-delegation / NONE / NONE |
| f03 | subagent-delegation | P,F,P | P,F,P | subagent-delegation / NONE / subagent-delegation |

Repeat totals `[2, 0, 1]` out of 3. Median 1, spread 2. 207,794 billable tokens, 135.7 seconds per
session.

Two facts follow. A spread of 2 means no change can be accepted at 3 repeats on this split, because
the delta can never exceed the spread when the total is 3. And the three repeats disagree on every
row, so this fixture measures a deck that does not reliably fire in natural mode: the same moment
reads a card once and nothing twice.

The next move for this skill is not an edit. It is either more repeats, or moments whose trigger is
unambiguous. Both are measurement changes, so both belong before this skill's round one, not inside
a round.

## First commands

    ./evals/loop.sh --self-test
    ./evals/loop.sh --check
    ./evals/loop.sh --freeze
    ./evals/loop.sh --label cal --split iterate --jobs 3

`cal` is the calibration round. No edit is made against it; it measures spend and the baseline.
