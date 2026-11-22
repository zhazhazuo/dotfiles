# Skill iteration loop

One procedure for every navigator skill. Each skill supplies a fixture, a split and a rule set.
The engine is shared, so a change to the measurement happens once and is recorded once.

    ~/.agents/skills/_harness/
      PROCEDURE.md            this file
      bin/skill-loop.sh       the runner, the freeze, the decision
      lib/score_routing.py    which card fired, and the three numbers, --self-test
      lib/score_artifact.py   whether the phase's exit artifact exists, --self-test
      lib/decide.py           median, spread, delta, stop rules, ledger, --self-test

    ~/.agents/skills/<skill>/evals/
      routing-moments.tsv     the fixture, with a split column and an artifact column
      rules-routing.json      the scorer's rule sets, frozen
      fixture-repo/           the tree the moments are posed in
      loop-config.json        repeats, jobs, cost ceiling, round cap
      freeze.json             sha256 of every frozen input
      loop.sh                 four lines that call the engine
      RESULTS.md              what the loop measured

Run directories are written to `~/.agents/eval-runs/<skill>/<label>/`, outside the repository,
because 30 transcripts per round is 10 MB. The score, the report and the ledger line are small
and are recorded in RESULTS.md.

## A round is three steps

1. **Tester.** A fresh agent at an independent root path runs the fixture and returns the report.
   It returns `report.tsv` verbatim: per moment, the ordered skill files read and the verdict of
   each repeat. It returns no summary, no cause, no recommendation.
2. **Editor.** One agent, or the parent, changes exactly one thing in `SKILL.md`, or in one card
   the deck names. The change carries one hypothesis, one section and one quote.
3. **Re-run.** The same tester procedure runs on the changed deck. `--decide` compares the two
   measurements and appends one ledger entry.

Two agents per iteration. The tester never edits. The editor never measures.

### Tester contract

The tester is spawned at a path outside the parent's tree, such as
`/dev-nav-loop-03-tester`, so no conversation history reaches it. Give it exactly this:

    run: ~/.agents/skills/dev-nav/evals/loop.sh --skill dev-nav --label <label> --split iterate
    return: ~/.agents/eval-runs/dev-nav/<label>/report.tsv and the four printed numbers

Blind it to the hypothesis, to the round, and to whether the label is a baseline or a candidate.
It must not read `PROCEDURE.md`, `RESULTS.md`, `runs/`, `freeze.json` or the ledger. A tester that
knows the hypothesis finds evidence for it.

### Editor contract

`coder`, or the parent. Never `refiner`: that type records to `~/.agents/skill-feedback/pending/`
and is forbidden to edit a skill. The editor states the hypothesis before the change and changes
one thing. A round with two edits measures neither.

## The frozen set

`--freeze` writes `freeze.json` with sha256 of the fixture, the rules, the fixture tree, and the
four instrument files. `--verify` exits 3 and names the first file that moved. Every measured run
verifies first, so a fixture edit or a scorer edit during the loop cannot read as improvement.
`RESULTS.md` records four scorer edits and five fixture edits from one earlier round; this freeze
exists to exclude that.

The deck is not frozen. The loop exists to change it. `deck_at_freeze` is recorded for provenance
and is not verified; the deck's hash keys the run cache, so a changed deck always produces fresh
runs.

`--refreeze` is legal only before round one, and the reason goes in `RESULTS.md`.

The rule sets live in `rules-routing.json`, not in the scorer, for the same reason: a rule change
must show as a hash change.

## The split

`routing-moments.tsv` names one of three splits per moment, in column 7.

| split | size | used for |
|---|---|---|
| `iterate` | 5 | the editor's target, and the accept decision |
| `holdout` | 5 | the stopping signal only, never shown to the editor |
| `sealed` | 3 | exactly one run, after the loop stops, on the final deck |

The held-out pass rate decides when to stop. The sealed set proves the result: no round measured
it, no edit was chosen against it. If the sealed and held-out results disagree, the loop fitted
the holdout.

## The measurement

Each moment runs 3 times per deck per split. A cell is `PASS` or `FAIL` by the rule in
`score_routing.py`: the expected skill must be read, and the first phase the agent enters must be
the expected phase. Orienting first and delegating after are legal. A negative control passes when
no dev card is read.

Each cell runs in a copy of `fixture-repo` under a fresh `mktemp -d` directory. The path states
neither the skill nor the repeat, because a session that reads its own path must not learn what is
being measured. The system prompt states the write boundary and does not announce an eval. The run
cache keys on the runner and the three scorers as well as the deck, so a repaired instrument never
reuses an older transcript.

The three numbers come from the transcript, never from judgement:

- skill files read per moment: the count of distinct `SKILL.md` reads.
- wall seconds per session: first timestamp to last in the transcript.
- `usage.cost.total`: summed over assistant messages. Some providers report 0; the same summary
  carries `tokens` so a ceiling still exists. The calibration round decides which ceiling applies.

The exit-artifact score is reported beside routing. It answers the question routing cannot: did
the phase produce its artifact. It is a presence rubric from `score_artifact.py`, frozen with the
fixture, and `--explain` prints which condition fired. The `progress` rubric requires an index and
a work-unit write, the nine canonical headings in injection order, a valid status and at most 1,600
characters in Tier 1. A fixture can put `progress` in the action column to include that rubric in
the cell verdict. The artifact column still reports it separately.

## Accept and stop

Set the thresholds before round one and record them in `loop-config.json`.

Accept a change only when both hold:

- the median pass count over 3 repeats moved by more than the spread of those repeats, where the
  spread is `max - min` of the 3 repeat totals, on either side;
- no moment that passed at baseline by majority now fails by majority.

Stop when any rule fires. `--stop` prints which one.

| rule | condition |
|---|---|
| `freeze` | a frozen file moved |
| `cost` | cumulative `usage.cost.total`, or total tokens, passed the ceiling |
| `delta-inside-spread` | the change sits inside the repeat spread |
| `holdout-flat` | held-out pass rate did not improve for 2 consecutive rounds |
| `round-cap` | round 6 |

A stopped loop reports its best round by median, ties to the smaller spread, never its best single
cell.

## What proves the result

None of it is the editor's or the tester's opinion.

1. The sealed split, run once on the final deck.
2. The A/B column against the baseline deck through `--deck-baseline`, which materializes a deck
   with `git show <ref>:AGENTS/skills/<skill>/SKILL.md`. Route mode only, because a natural run
   reads the installed deck.
3. The three repeats behind every accepted change.
4. The transcripts, so `--reuse` re-scores the table with no model calls.
5. The measured spend of the whole loop.
6. A `second-thought` verdict on the final diff. Parity is an allowed answer.

## Commands

    ~/.agents/skills/dev-nav/evals/loop.sh --self-test
    ~/.agents/skills/dev-nav/evals/loop.sh --skill dev-nav --freeze
    ~/.agents/skills/dev-nav/evals/loop.sh --skill dev-nav --label cal --split iterate
    ~/.agents/skills/dev-nav/evals/loop.sh --skill dev-nav --reuse cal
    ~/.agents/skills/dev-nav/evals/loop.sh --skill dev-nav --decide --baseline cal --candidate r01 \
      --hypothesis "..." --section "Where to enter" --quote "..." --change "..."
    ~/.agents/skills/dev-nav/evals/loop.sh --skill dev-nav --stop
    ~/.agents/skills/dev-nav/evals/loop.sh --skill dev-nav --deck-baseline 053a9cb \
      --label ab-base --mode route --split sealed

A scorer change is the one edit that can turn a regression into progress. `--self-test` runs one
synthetic pass and one synthetic fail through each scorer, a freeze test on a fixture edit, and a
freeze test on a fixture-tree edit. Run it before every round.
