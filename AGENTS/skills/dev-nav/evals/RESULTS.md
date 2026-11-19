# dev-nav routing eval — results

The loop ran one round and accepted no change. The deck is the deck it was. What changed is the
instrument: a shared frozen harness, an exit-artifact scorer, and a split that separates the
moments the loop tuned on from the moments it did not.

## The instrument

`~/.agents/skills/_harness/` holds the procedure and one engine. `evals/loop.sh` is four lines
that call it. The engine runs the fixture, scores it, compares two rounds, and appends a ledger
entry. It never chooses an edit.

- `lib/score_routing.py` — which card fired, from `rules-routing.json`, plus the three numbers.
- `lib/score_artifact.py` — whether the phase produced its exit artifact.
- `lib/decide.py` — median, spread, delta, the five stop rules, the ledger.
- `--self-test` on each, and on the engine, which also proves a fixture edit and a fixture-tree
  edit both fail `--verify`.

`run-routing-eval.sh` still works and now calls the shared scorer, so the old entry point and the
new one cannot disagree.

## The frozen set

`freeze.json` (written 2026-11-19) holds sha256 of `routing-moments.tsv`, `rules-routing.json`, the
fixture tree, and the four instrument files. The four rule sets left the scorer and now live in
`rules-routing.json`: `own_skills`, `orient_skills`, `delivery_skills`, `phases`. This is the
overfit the previous record admitted to, excluded by construction: a scorer or fixture edit now
exits 3 and names the file.

The freeze was renewed seven times, four before round one and three after the round closed,
every time for a stated defect:

1. the fixture had no split column;
2. the deck tree was inside the freeze, which forbade the loop from changing the deck;
3. the sealed rows were missing the split column, caught by `--check`;
4. `score_routing.py` gained `tokens_billable`;
5. the read extractor split a shell command into junk skill names;
6. `--stop` could not see the decision, so the delta rule could not fire;
7. `--deck-baseline` left the mode at natural, so the A/B measured the live deck twice.

Renewals 5 to 7 happened after round one closed. They change no verdict except one baseline cell,
shown below.

## The split

| split | size | used for | measured |
|---|---|---|---|
| iterate | 5 | the editor's target, the accept decision | every round |
| holdout | 5 | the stopping signal, never shown to the editor | every round |
| sealed | 3 | one run on the final deck | once, after the loop |

The fixture grew so the five `natural_ok=no` rows became scorable: nine source files, a PRD
(`docs/prd/invoices.md`), a decisions document (`docs/decisions/caching.md`), a React screen
`web/InvoiceScreen.tsx`, an untested parser, and 400 mock-only tests in `test/mocks/`. All 13 rows
are now `natural_ok=yes`.

## Thresholds, set from the calibration round

The calibration (`cal`, 15 cells, 3 repeats) measured 386,908 billable tokens and 50 seconds per
session. `usage.cost.total` is 0 on `qoder/DeepSeek-Flash`, because the provider reports no price,
so the ceiling is set on `input + output + cacheWrite`: 3,000,000 tokens, about four full rounds.
Round cap 6. Held-out patience 2. A change is accepted only when the median moves by more than the
spread of the 3 repeat totals and no moment that passed at baseline now fails.

## Round 1

Baseline `r01-base` was produced by a blind tester at `/dev-nav-loop-01-tester`. Iterate totals
`[3, 4, 4]`, median 4, spread 1.

**Hypothesis.** The natural-mode misses on `m01` read no card at all. The description never states
that the deck is read before the first edit, so one sentence there converts a no-read into a card
read on a small change, and does not fire on the deployment control.

**The one edit.** In the frontmatter description, after "pruning low-signal tests.": "Read this
deck before the first edit on any change to code."

**The re-run.** A second blind tester at `/dev-nav-loop-01-tester-b` produced `r01`: iterate totals
`[3, 3, 4]`, median 3, spread 1.

    split=iterate baseline=[3, 4, 4] candidate=[3, 3, 4] spread=1 delta=-1
      -> REJECT (regression:m01:2/3->1/3)

**The verdict.** Rejected, and `--stop` reports `delta-inside-spread`: a delta of 1 sits inside a
spread of 1, so the change is not distinguishable from repeat noise. The edit was reverted. The
deck is byte-identical to `053a9cb:AGENTS/skills/dev-nav/SKILL.md`.

Ledger: `fb-20261119T045818Z-d150` in `~/.agents/skill-feedback/records.jsonl`.

## The sealed run

Three moments, one deck, one run, never measured during the loop. Nine cells, 8 pass.

| id | phase | expected | verdicts | artifact | median |
|---|---|---|---|---|---|
| m17 | 1 | ripwire-router | F,P,P | F,P,P | 2/3 |
| m18 | 4 | write-discoverable-code | P,P,P | P,P,P | 3/3 |
| m19 | 5 | ripwire-find-bug | P,P,P | P,F,P | 3/3 |

Sealed totals `[2, 3, 3]`, median 3, spread 1. The holdout median was 4. The one sealed miss is
`m17` repeat 1, which read no card; the other two repeats read `ripwire-router` and stopped.

## A/B against the pre-card-book deck

`--deck-baseline 2cac951` materializes the flat 13-row table that the card book replaced on
2026-10-08. Both sides run route mode on the sealed split.

| id | flat table (2cac951) | card book |
|---|---|---|
| m17 | P,P,P | P,P,P |
| m18 | F,F,P | F,F,F |
| m19 | P,F,P | P,P,P |
| repeat totals | 2, 1, 3 | 2, 2, 2 |
| median | 2 | 2 |
| spread | 2 | 0 |
| skill files read per moment | 5.22 | 3.56 |
| wall seconds per session | 84.3 | 22.0 |

The honest reading: **parity on the median, and a loss on one moment.** The flat table passes
`m18` in one repeat and the card book in none, because route mode sends the card book into phase 1
first, and the frozen rule scores the entry phase. The card book wins `m19` in all three repeats
where the flat table wins two. The tie is compensation, not equivalence.

Two other differences point the same way. The card book's spread is 0 against 2, so its result is
more stable. It reads 32 per cent fewer skill files per moment. And the flat table routes to four
skills that left the machine on 2026-10-28 — `test-driven-development`,
`verification-before-completion`, `systematic-debugging`, `requesting-code-review` — which the pass
count does not see, because a read of a missing skill still counts as a read.

The A/B against `053a9cb` that was asked for would compare the deck to itself: that commit is
byte-identical to the current deck. It is not run, because the answer is known by hash.

## Spend

| run | cells | new cells | billable tokens | wall seconds per session |
|---|---|---|---|---|
| smoke | 5 | 5 | 136,681 | 43.5 |
| cal | 15 | 10 | 386,908 | 49.9 |
| r01-base | 15 | 0 (cache) | 0 | 49.9 |
| r01 | 15 | 15 | 342,035 | 45.0 |
| r01h | 15 | 15 | 538,405 | 80.5 |
| s1 (sealed) | 9 | 9 | 254,789 | 51.9 |
| ab-old | 9 | 9 | 254,667 | 84.3 |
| ab-new | 9 | 9 | 207,869 | 22.0 |

Distinct spend for dev-nav: 1,984,673 billable tokens, 0.00 USD as reported. The engine counts a
cached copy a second time when a label reuses a cache key, so `--stop` reports 1,790,937 for the
runs it sees; the table above is the honest count.

## Instrument defects the loop found

1. **A run started before an instrument edit reads the file incrementally and dies on a syntax
   error.** The first round wrote all 30 transcripts and then failed to score them. The transcripts
   were scored with `--reuse` after a renew; no model calls were repeated. Do not edit the engine
   while a run is in flight.
2. **The read extractor counted a shell command as N skill reads.** `wc -l a/SKILL.md b/SKILL.md`
   became reads of `a`, `b` and a junk name. Fixed to count `read` tool calls and shell commands
   that open the file. Re-scoring every saved label changed one cell: `m01` repeat 3 at baseline,
   FAIL to PASS, because the agent had read the card with `cat`. The baseline median moved 3 to 4,
   which makes the candidate look worse, not better.
3. **`score.json` recorded the deck hash at scoring time, not at run time.** Two decks could share
   a hash. Fixed with `cache-sig.txt` and `deck-hash.txt` in the run directory. The round 1
   provenance is proven by the cache: `r01-base` came from sig `32e364d3…` (15 files) and `r01`
   from sig `acf7266d…` (30 files).
4. **`--stop` read the score files but not the decision**, so the delta rule could never fire. It
   now reads `decision.json`.
5. **`--deck-baseline` did not force route mode**, so an A/B would have measured the live deck
   twice.

## Second thought on the diff

An independent `second-thought` agent read the procedure, the three scorers, the engine, this file
and the fixture. Verdict: **stands with caveat**. It raised four objections, recorded here in its
terms.

1. **The A/B table contradicted its own medians.** The first version of the table printed
   `m18 | F,F,P | P,P,P`, which gives the card book 3/3, not the 2/3 in the same table. The
   objection was correct and the error was mine: `ab-new` scores `m18` `F,F,F`. The table is
   corrected above, and `repeat_totals` in `score.json` is the authority. The verdict line changed
   from "parity on the pass count" to "parity on the median, and a loss on one moment", which is
   the weaker and true claim.
2. **`delta-inside-spread` is both a reject reason and a stop rule.** At 5 moments and 3 repeats a
   real improvement of 1 can never exceed a spread of 1, so the first edit that lands inside noise
   ends the loop. The stop is what the owner specified, and it makes the loop close to one round by
   construction. The evidence is about one edit, not about the deck.
3. **The holdout is not blind.** All splits live in one fixture file, the parent is the editor, and
   the parent read the holdout after the round. The separation is procedural. It is recorded under
   "What this does not show", and it is the weakest part of the design.
4. **The artifact rubric is presence only, and two of its codes cannot fire in route mode.**
   `check_handoff` passes on a routing transcript that names a skill and a next action.
   `testfirst`, `mock` and `split` need file writes that route mode forbids. The rubric measures
   presence, as stated, and the flat-navigator codes are the weakest.

What it confirmed: the round one decision is backed by the frozen numbers, and the 32 per cent
reduction in skill files read computes from the saved transcripts.

## What this does not show

1. One round, one hypothesis, one edit. A rejected edit is not a test of the deck.
2. The artifact scorer is a presence rubric. It says whether a map, a test, a root cause or an
   evidence request exists. It does not say whether the artifact is good.
3. Three repeats per cell is a small sample. The spread rule is what protects against reading noise
   as progress, and it is the rule that stopped the loop.
4. `qoder/DeepSeek-Flash` reports no price. The spend figures are tokens, not money.
5. The holdout was read by the parent at the end of the round, so it did not inform the edit; but
   the parent is the editor, and that separation is procedural, not enforced.
6. The other four navigators are bootstrapped and frozen, and only `dev-flow-nav` has a calibration
   run. Their loops are unrun.


---

# The previous record (2026-10-28, kept verbatim)

> **Pre-change record, dated before 2026-10-28.** These results measure the ten-phase deck. On
> 2026-10-28 the `obra/superpowers` package left the machine, four phases left the deck, and the
> fixture lost six moments. The numbers below still describe the deck as it was measured; they are
> not a verdict on the six-phase deck. Re-run `evals/run-routing-eval.sh` to measure that.

This is the evidence behind the card-book refactor. It records what was measured, what the
measurement found, and what it does **not** show.

## What this measures

Whether an agent, given a dev moment, enters the correct lifecycle phase and reads the skill that
governs it. It does **not** measure whether the agent then obeys that skill, or produces the
phase's exit artifact. See "What this does not show" below.

## Method

- **Fixture:** `evals/routing-moments.tsv`, 16 moments. 13 are positive (a specific phase is
  correct), 1 is an ambiguity prober pair (`m14`, `m15`), 1 is a negative control (`m16`, a
  non-dev moment where the deck must not route to a dev card).
- **Harness:** `evals/run-routing-eval.sh`. One fresh `pi -p` session per moment, in a scratch copy
  of `evals/fixture-repo`. Transcripts are written outside the agent's cwd, because a transcript
  written into the cwd is grepped by the agent under test and corrupts the run.
- **Modes:**
  - `--mode route` (diagnostic): the agent is told its job is to route, and is pointed at the deck.
  - default (acceptance): the bare moment only. Nothing tells the agent that skills exist.
- **Scoring:** the expected skill must be read, and the first phase the agent *enters* must be the
  expected phase. Orienting first is always legal. Movement after entry is not scored: the
  lifecycle may go forward, and may go backwards into a repair phase such as Debug or Trim.
- **Model:** the pi default, `qoder/DeepSeek-Flash`, pi 1.1.0. All figures are single-run.

## Results

Route mode, new deck, all 16 moments: **16 pass, 0 fail.** Transcripts:
`$TMPDIR/devnav-eval.Dx3J85/transcripts` (re-scored with
`--reuse`, no model calls).

Natural mode, new deck, 13 scorable moments: **11 pass, 0 fail, 5 skipped.**

| id | phase | expected | reads (natural mode) | result |
|---|---|---|---|---|
| m01 | 5 | write-discoverable-code | ripwire-router, ripwire-navigate, write-discoverable-code | PASS |
| m02 | 6 | systematic-debugging | systematic-debugging | PASS |
| m03 | 1 | ripwire-router | — | SKIP |
| m04 | 4 | test-driven-development | test-driven-development | PASS |
| m05 | 2 | alignment-quiz | — | SKIP |
| m06 | 3 | context-to-qa-scenarios | — | SKIP |
| m07 | 8 | verification-before-completion | verification-before-completion | PASS |
| m08 | 9 | requesting-code-review | requesting-code-review, ops-nav, pea-shooter | PASS |
| m09 | 9 | receiving-code-review | receiving-code-review | PASS |
| m10 | 7 | prune-low-signal-tests | prune-low-signal-tests | PASS |
| m11 | 5 | api-mock | — | SKIP |
| m12 | 5 | structuring-ui-components | — | SKIP |
| m13 | 10 | writing-skills | writing-skills | PASS |
| m14 | 8 | verification-before-completion | verification-before-completion | PASS |
| m15 | 1 | ripwire-router | ripwire-write-tests, ripwire-router | PASS |
| m16 | — | (negative control) | NONE | PASS |

Skipped moments are marked `natural_ok=no` in the fixture, with the reason in its last column.

Deck revision: the route transcripts were produced after every routing change (the phase-5
condition gate, the entry rule, the 8/9 boundary, the card 04 fix, the `council-mode` removal). The
only edit made after them deleted a wording clause in Handoffs that names no trigger, so the frozen
transcripts remain the scoring basis.

## A/B against the pre-refactor deck

The old 13-row table was recovered with
`git show HEAD:AGENTS/skills/dev-nav/SKILL.md` and run through the same fixture, same mode, same
model:

    ./evals/run-routing-eval.sh --mode route \
      --deck-path /tmp/devnav-baseline/dev-nav/SKILL.md \
      --only m02,m11,m12,m14,m15,m16

| id | old deck | new deck |
|---|---|---|
| m02 | PASS | PASS |
| m11 | PASS | PASS |
| m12 | PASS | PASS |
| m14 | PASS | PASS |
| m15 | PASS | PASS |
| m16 (negative control) | **FAIL** — routed to `verification-before-completion` | **PASS** — abstained |

**The honest reading: on positive moments, the refactor shows parity, not improvement.** The old
table routes a positive dev moment correctly. The only measured gain is the negative control: the
old flat table has no way to say "this is not a dev phase", so it forced a dev card onto a
deployment task.

The card book's other claimed properties (phase ordering, exit artifacts, the admission test) are
**not measured by this fixture**. They are structural claims with no evidence here. See below.

## What this does not show

1. **No pre-refactor natural-mode baseline.** The old deck was only run in route mode. The
   acceptance-mode comparison is missing.
2. **No exit-artifact measurement.** The central claim of the card book is that a phase is a gate
   with an exit artifact. Nothing here tests whether an agent, at phase 5, states the search test
   for its new names, or, at phase 8, produces the command output. That needs a second fixture that
   scores the agent's *output*, not its routing. This is the measurement that would justify the
   refactor on evidence.
3. **Single runs.** One run per cell. The reply-benchmark precedent in this workspace
   (`AminBlg/SimpleEnglish`) treats a single run as roughly ±0.5 on its scale; read these as
   pass/fail signals, not rates.
4. **A small model.** `qoder/DeepSeek-Flash`. A stronger model may route well from the bare
   description without any deck, which would compress the difference further.
5. **A small fixture repo.** Four files and no frontend. Five moments are therefore unscorable in
   natural mode.

## Corrections forced by the runs

Recorded so the reader can judge how much of the result is design and how much is fitting.

### Deck defects the runs found (real, fixed)

1. **Phase 5 listed three skills in a sequence.** `m11` read `write-discoverable-code` and stopped,
   never reaching `api-mock`. Fixed: phase 5 is now selected by condition, not read in order.
2. **No entry rule.** The deck read as "always start at phase 1", so `m14` and `m15` both routed to
   `ripwire-router` and stopped. Fixed: added "Where to enter", which says to enter at the phase
   whose trigger matches and that phase 1 is for code you must change but have not mapped.
3. **Phases 8 and 9 were not disambiguated.** `m14` ("check my work") routed to phase 9. Fixed:
   added a boundary line, "8 before you state a claim, 9 before you merge".
4. **Phase 4 did not name the existing-code route.** `m15` ("add a test for the parser") went to
   `ripwire-write-tests`, which is correct for code that already exists, but no card said so. Fixed:
   card 04 now names that route.
5. **A dead path.** The deck routed to `council-mode` at a path that does not exist on this machine
   (there is no `pi-subagents` package and no `council-mode` skill anywhere under `~/.pi`). Removed.
   `ops-nav` was checked for the same reference and does not carry it; all 14 of its routed paths
   resolve.

### Harness and scoring defects (mine, fixed)

1. `pi` inherited the fixture file as stdin and consumed it, so the loop stopped after one moment.
   Fixed with `< /dev/null`.
2. The extractor recorded only the first skill read, so a legitimate orient-then-implement walk
   scored as a miss. Fixed: it now records every skill read.
3. The scoring rule allowed only the expected phase's skills plus orient skills, so it failed
   correct forward walks (`m01`, `m10`) and the phase-9 pair (`m08`). Fixed: scoring now checks the
   phase the agent **enters**, and does not score movement after entry.
4. Route mode originally forced a single-phase answer, which is wrong for a moment that spans
   orient then implement. Fixed: it now asks for the phases the task passes through.

### Fixture corrections

1. `m16` originally expected no skill at all. Routing to `ops-nav` is correct — "no dev phase" does
   not mean "no skill". Fixed: a negative control now passes on any non-dev outcome.
2. `m15`'s expectation was corrected from phase 4 to phase 1 after run 1, because the parser in the
   moment already exists, which makes `ripwire-write-tests` via phase 1 the correct route. The
   original intent (distinguish adding a test from pruning one) is preserved.
3. Five moments were marked `natural_ok=no` after their natural runs, each with the reason: the
   fixture is too small to need orienting (`m03`), ships no PRD (`m06`), ships no frontend (`m11`,
   `m12`), or presumes a session that already made decisions (`m05`).

## Re-run

    cd ~/.agents/skills/dev-nav
    ./evals/run-routing-eval.sh                                    # acceptance, all scorable moments
    ./evals/run-routing-eval.sh --mode route                       # diagnostic, all 16
    ./evals/run-routing-eval.sh --reuse <dir>/transcripts          # re-score saved runs, no model calls
    ./evals/run-routing-eval.sh --only m02,m11                     # subset
    ./evals/run-routing-eval.sh --model <id>                       # another model