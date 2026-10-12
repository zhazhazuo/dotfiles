# Reply-style measure: results

The rule under test is the `## Reply Style` section in `AGENTS.md`, which is injected
into every session. This measure scores agent replies against it.

## What is scored

| Class | Meaning | Target |
|---|---|---|
| `HARD` | em-dash, contraction, opener, closer | 0 |
| `SLOP` | a word with no fact, from the rule 10 list and `references/word-swaps.md` | 0 |
| `DECORATOR` | bold, header, bullet, table row, horizontal rule, emoji | reported, not failed |
| `SHAPE` | the reply's structure against the shape its prompt needs | 0 defects |

`SHAPE` is the class this measure exists for. Each prompt declares what its answer
needs before the answer exists. A prompt that needs labels and gets none scores
`MISSING`. A prompt that needs none and gets a heading, a list, or a table scores
`SPURIOUS`.

## Reproduction

```sh
cd AGENTS/skills/simple-english
./evals/capture-replies.sh /tmp/reply-run          # 8 fresh pi sessions, no session reuse
./evals/capture-replies.sh --only 7 /tmp/reply-one  # re-capture a single prompt
python3 evals/count-reply-defects.py --prompts evals/reply-prompts.txt /tmp/reply-run/*.md
```

The counter is validated against control files before use. `--json` gives machine
output. Model: `qoder/DeepSeek-Flash`, thinking level `high`, pi `1.1.0`.

## Result

Three runs per condition, 24 replies each. Same prompt set, same model.

| | baseline (prose-only rule) | after (judgment rule) |
|---|---|---|
| `MISSING` | 12 of 24, 50% | 4 of 24, 17% |
| `SPURIOUS` | 0 of 24, 0% | 0 of 24, 0% |
| ok | 12 of 24, 50% | 20 of 24, 83% |
| `HARD` | 0 | 0 |
| `SLOP` | 0 | 0 |
| `DECORATOR` | 0 | 61 |
| words | 6,313 | 6,518 |

The two rules differ in exactly one visible way. The prose-only rule produced no
heading, list, or table in any of the 24 replies. The judgment rule produced some
structure where the content needed it, and none where it did not.

## Per prompt

`B` is the baseline, `A` is after. Each column is one run.

| # | needs | B r1 | B r2 | B r3 | A r1 | A r2 | A r3 | prompt |
|---|---|---|---|---|---|---|---|---|
| 1 | structure | MISSING | MISSING | MISSING | ok | MISSING | MISSING | Summarize the tradeoffs between polling and webhooks |
| 2 | structure | MISSING | MISSING | MISSING | MISSING | ok | MISSING | Compare optimistic and pessimistic locking |
| 3 | structure | MISSING | MISSING | MISSING | ok | ok | ok | Review this plan: cache the user profile in Redis |
| 4 | structure | MISSING | MISSING | MISSING | ok | ok | ok | Our deploy failed at the migration step |
| 5 | prose | ok | ok | ok | ok | ok | ok | What port does Postgres listen on by default |
| 6 | prose | ok | ok | ok | ok | ok | ok | Which HTTP status code means the request was valid but not permitted |
| 7 | prose | ok | ok | ok | ok | ok | ok | What is the default port for HTTPS |
| 8 | prose | ok | ok | ok | ok | ok | ok | Is a 200 response with an error message in the body a good API design |

## Reading

The prose-only rule failed every structure prompt, in every run: 12 of 12. It never
produced a heading, a list, or a table anywhere. That is the wall of prose the
operator reported.

The judgment rule fixed prompts 3 and 4 completely, in all three runs. It left 1 and
2 inconsistent: sometimes a table or a list, sometimes a wall of prose. All four
prose prompts stayed prose in every run, so the default holds and the rule does not
over-structure.

The remaining defect is narrow. Prompts 1 and 2 ask for a tradeoff and a comparison
inside one short sentence, and the rule does not reliably decide that such an answer
has parts. Prompts 3 and 4, which carry more explicit questions, are decided
correctly every time. A candidate fix is to name that case in the rule: a comparison
or a tradeoff with several items is a set of parts.

## Retracted probe, and how it was fixed

Prompt 7 was "Is a 30 second timeout appropriate for a health check endpoint?" It
scored `SPURIOUS` in two after runs. That score was wrong. The question is
single-point, so the shape label said prose, but the answer contained a four-way
comparison of caller types, and the rule allows a table for three or more compared
items. The reply was defensible and the label was wrong.

The probe is replaced by "What is the default port for HTTPS?", a single fact with
nothing comparable in the answer. The six affected replies are preserved at
`/tmp/reply-v2-retracted-p7/`. With the new probe, `SPURIOUS` is 0 in both
conditions, in all three runs each.

## Known limits

**The `SLOP` class does not discriminate here.** It scored 0 in both conditions, so
it measures nothing on this prompt set. It catches `leverage`, `robust`, and the
other words on the two upstream lists. It cannot catch an undefined abstraction such
as "asymmetry" or "ground truth", which is one of the defects the operator reported.
Word choice in replies has no automated check in this harness. The reading that
remains is a human rating.

**The judgment is stochastic.** Prompts 1 and 2 disagree with themselves across runs.
A single run per prompt reports noise as signal.

**One model, no ablation.** Single model, single thinking level. The measure does not
show which sentence in the rule does the work. Candidate ablations are to drop the
pre-send check, and to drop the word-choice rules, and re-measure each.
