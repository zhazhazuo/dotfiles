# progress-tracking routing and output eval — results

Bootstrapped on 2026-11-22 from the shared harness at `~/.agents/skills/_harness/`. Series 1 was
rejected and reverted. Series 2 accepted the same schema-order edit on a valid creation fixture.

## What this fixture measures

The routing verdict records whether the session read `progress-tracking/SKILL.md`. The `progress`
output check requires an index write and a work-unit write. The unit must use the nine canonical
headings in the reader's injection order, with no extra level-two headings and a valid status.
The action column applies that output check to the cell verdict, so an edit can move the decision.
The artifact column reports the same output check beside routing.

## The split

Five iterate moments cover creation, update, archive, user blockers and distillation. Three holdout
moments cover completion, the Tier 1 budget and Context, with two negative controls. Two sealed
moments cover creation and archive, with one negative control.

## Thresholds

Three repeats per cell, three jobs, 3M billable tokens for the whole loop, six rounds and two rounds
of holdout patience. Accept only a median delta larger than the repeat spread, with no majority
regression on a moment that passed at baseline.

## Calibration

`cal` ran on 2026-11-22 with 15 cells, three repeats and three jobs. It spent 239,163 billable
tokens. The provider reported 1,437,115 total tokens. Mean wall time was 19.0 seconds per session.
The 3M billable-token ceiling stays unchanged.

The first scoring pass reported zero passes because the progress rubric combined every read result
and write fragment into one heading list. It also counted `read` calls as writes. Two synthetic
regression cases reproduced the defect before the repair. The scorer now requires an actual write
or edit, and it evaluates each complete work-unit document separately.

Re-scoring the saved transcripts with `--reuse cal` produced iterate totals `[4, 3, 2]`. The median
is 3 and the spread is 2. `p01`, `p03` and `p04` passed by majority. `p02` never read the skill.
`p05` passed twice. No model calls were needed for the repair.

## Refreeze before round one

The refreeze records the attribution repair above. The fixture, rules, thresholds and deck are
unchanged. Only `score_artifact.py` moved. The repaired scorer's self-test and the shared loop
self-test pass before the refreeze.

## Holdout baseline

`calh` spent 255,463 billable tokens and produced holdout totals `[3, 5, 3]`. The median is 3 and
the spread is 2. Both negative controls passed on every repeat. `h05` passed on every repeat.
`h01` and `h03` each passed once.

## Round 1

Hypothesis: aligning the schema example with the reader's injection order would reduce old-order
progress files. The only edit moved Open Questions and Next before Decisions, Constraints and
Assumptions in the `Progress File Format` example.

`r01` spent 233,648 billable tokens and produced iterate totals `[3, 1, 4]`. The median stayed at
3. The spread was 3 and the delta was 0. `p01` regressed from two passes to one. The decision was
**REJECT**, reason `regression:p01:2/3->1/3`, ledger entry `fb-20261122T104056Z-756b`. The edit was
reverted. `git diff --exit-code -- AGENTS/skills/progress-tracking/SKILL.md` then returned 0.

`--stop` fired `delta-inside-spread`. The loop stopped after one round.

## Sealed split

`sealed1` ran once on the reverted deck. It spent 216,583 billable tokens and produced sealed
totals `[3, 3, 3]`. All three moments passed on every repeat, including the negative control.

## Final review

The independent `second-thought` verdict was `stands`. It confirmed parity with the baseline by
comparing the working-tree blob with `HEAD:AGENTS/skills/progress-tracking/SKILL.md`. There is no
final deck diff, so an A/B run has no changed deck to measure.

## Spend

The four measured runs spent 944,857 billable tokens in total. The provider reported 6,170,329
total tokens. The ceiling was 3M billable tokens.

## Next iteration

Revise the fixture before another round. The baseline median is 3 of 5 and its spread is 2, so the
largest possible median gain cannot exceed the baseline spread. Also, `p02` never read the deck
in any baseline repeat. That routing failure occurs before the deck can shape the session.

## Series 2 refreeze before its first valid round

The first series is void for iteration because its accept rule had no reachable success condition.
Its four run directories and decision file moved to `~/.agents/eval-runs/progress-tracking-v1/`.
The fixture and fixture repository moved to `routing-moments-v1.tsv` and `fixture-repo-v1/`. The
rejected edit and its ledger entry remain in this record.

Series 2 measures only creation. Every positive moment names the deck explicitly, which models
`/seal` dispatch and removes routing variance that the deck cannot change. The fixture repository
has no progress directory, so no injected `<progress-state>` supplies the section order. The deck
is the only source of that order. The rubric, thresholds and deck are unchanged from series 1.

## Series 2 calibration

`cal2` spent 175,426 billable tokens and produced iterate totals `[1, 0, 1]`. The median is 1 and
the spread is 1. Every positive cell read the deck. Every failed cell wrote the old section order.
The two passes wrote the canonical order.

`cal2h` spent 162,995 billable tokens and produced holdout totals `[2, 3, 2]`. The median is 2 and
the spread is 1. Both negative controls passed on every repeat. Every positive holdout cell read
the deck.

## Series 2 round 1

Hypothesis: without injected progress state, aligning the schema example with the reader's
injection order would increase canonical progress files. The only edit moved Open Questions and
Next before Decisions, Constraints and Assumptions.

`r01` spent 173,290 billable tokens and produced iterate totals `[5, 5, 4]`. The median rose from
1 to 5. The spread was 1 and the delta was 4. No moment regressed. The decision was **ACCEPT**,
reason `outside-spread`, ledger entry `fb-20261122T122746Z-a5a2`.

`r01h` spent 164,682 billable tokens and produced holdout totals `[5, 5, 5]`. Every holdout moment
passed on every repeat. The holdout median rose from 2 to 5. No engine stop rule fired. The loop
ended because the iterate median had reached its maximum of 5.

## Series 2 sealed split

`sealed2` ran once on the accepted deck. It spent 190,238 billable tokens and produced sealed
totals `[3, 3, 2]`. The median was 3 of 3. `s01` failed once because the session did not write the
index. Every sealed cell read the expected deck or abstained as required.

The `r01` and `sealed2` deck hashes are identical:
`a4d8812e97b505a65c1c4e368ac425e3a4883d160e1b5b7b74ce2ccc29dde8ea`. The baseline hash differs.
The sealed run therefore measured the accepted edit.

## Series 2 final review

The independent `second-thought` verdict was `stands-with-caveat`. It confirmed that the diff only
moves the two sections and matches the file's tier table. The caveat is evidential: the sealed split
has no baseline, so it cannot prove the effect size. The delta of 4 belongs to the iterate split.
The sealed run proves the final deck's behavior, not a sealed before-and-after delta.

## Series 2 spend

The five measured runs spent 866,631 billable tokens in total. The provider reported 7,897,287
total tokens. The ceiling was 3M billable tokens.
