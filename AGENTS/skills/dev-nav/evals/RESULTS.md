# dev-nav routing eval — results

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
