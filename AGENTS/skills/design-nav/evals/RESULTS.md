# design-nav routing eval — results

Bootstrapped on 2026-11-19 from the shared harness at `~/.agents/skills/_harness/`. No round has
run against this deck. This file records the measurement, not a verdict.

## What is frozen

`evals/freeze.json` holds sha256 of `routing-moments.tsv`, `rules-routing.json`, the fixture tree,
and the four instrument files. `./evals/loop.sh --verify` exits 3 when one moves. `loop-config.json`
holds the thresholds.

## The split

5 iterate (d01-d05), 3 holdout (d06-d08), 2 sealed (d09-d10).

## Thresholds

Set from the dev-nav calibration, because the same provider and the same instrument produce the
spend: 3 repeats per cell, 3M billable tokens for the whole loop, 6 rounds, 2 rounds of patience on
the held-out rate. A change is accepted only when the median moves by more than the repeat spread
and no moment that passed at baseline now fails.

## First commands

    ./evals/loop.sh --self-test
    ./evals/loop.sh --check
    ./evals/loop.sh --freeze
    ./evals/loop.sh --label cal --split iterate --jobs 3

`cal` is the calibration round. No edit is made against it; it measures spend and the baseline.
