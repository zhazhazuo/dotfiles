# Reply-style measure: results

The rule under test is the `## Reply Style` section in `AGENTS.md`, which is injected
into every session. This measure scores agent replies against it.

The counter is `evals/score-replies.py`. It imports `evals/ste_lint.py` and
`evals/slop.tsv`, both vendored verbatim from `github.com/AminBlg/SimpleEnglish` at
commit `a6fcb4f`, and adds only what the reply register needs and the STE linter does
not model. The hand-written `count-reply-defects.py` it replaces is deleted; its
duplicate regexes and its shorter word list were the reason for the swap.

## What is scored

| Class | Meaning | Target |
| --- | --- | --- |
| `HARD` | em-dash, contraction, opener, closer | 0 |
| `SLOP` | a word or phrase with no fact, from the vendored lexicon plus 14 reply-register terms | 0 |
| `DECORATOR` | bold, header, bullet, table row, horizontal rule, emoji | reported, not failed |
| `STE` | sentence over 20 words, banned modal, perfect tense, ing clause, semicolon, Latin abbreviation, trailing condition, synonym rotation | 0 |
| `SHAPE` | the reply's structure against the shape its prompt needs | 0 defects |

`SHAPE` is the class this measure exists for. Each prompt declares what its answer
needs before the answer exists. A prompt that needs labels and gets none scores
`MISSING`. A prompt that needs none and gets a heading, a list, or a table scores
`SPURIOUS`.

The 14 reply-register slop terms exist because the vendored lexicon misses them, and
`--self-check` proves none of them is already matched there, so no reply is counted
twice for one word.

## Reproduction

```sh
cd AGENTS/skills/simple-english
python3 evals/ste_lint.py --self-test          # the vendored linter's own control
python3 evals/score-replies.py --self-check    # the addendum adds no double count
./evals/capture-replies.sh /tmp/reply-run      # 8 fresh pi sessions, no session reuse
python3 evals/score-replies.py --prompts evals/reply-prompts.txt /tmp/reply-run/*.md
python3 evals/score-replies.py --lead /tmp/reply-run/*.md   # judge the ordering
```

`--json` gives machine output. Model: `qoder/DeepSeek-Flash`, thinking level `high`,
pi `1.3.0`, captured 2026-10-20.

## Result under Issue 9

The rule changed twice on 2026-10-21. First `## Reply Style` applied ASD-STE100 Issue 9 to replies,
which made the Plain baselines below obsolete. Then the ordering bullet gained the name "Pyramid
Principle" and a grouping clause, and a third capture added the scope clause that exempts a
one-fact answer. Three captures, one reply per prompt, same model.

| Measure | Issue 9 | + Pyramid name | + scope clause |
| --- | --- | --- | --- |
| words | 1,860 | 2,195 | 1,729 |
| `HARD` | 0 | 0 | 0 |
| `SLOP` | 0 | 0 | 0 |
| `STE` | 24 | 39 | 22 |
| `STE` per 100 words | 1.29 | 1.78 | 1.27 |
| `DECORATOR` | 0 | 0 | 0 |
| `SHAPE` `MISSING` | 4 of 9 | 4 of 9 | 4 of 9 |
| `SHAPE` `SPURIOUS` | 0 of 9 | 0 of 9 | 0 of 9 |

Naming the method and demanding grouped arguments raised length by 18 percent and the `STE`
residual by 62 percent. The growth was not in the prompt that justifies grouping: the status
report stayed flat at 298 to 300 words, while the two prompts that need no grouping grew most
(prompt 2 from 246 to 482 words, prompt 8 from 184 to 296). The one-sentence factual answers grew
too, 23 to 40 and 41 to 51 words, because the grouping clause invited support the question never
asked for. The scope clause recovered all of it and ended below both earlier runs: 1,729 words and
`STE` 22.

| # | needs | words / `STE` per configuration |
| --- | --- | --- |
| 1 | structure | 260/5, 272/7, 245/4 |
| 2 | structure | 246/3, 482/8, 299/6 |
| 3 | structure | 333/5, 307/6, 213/2 |
| 4 | structure | 434/7, 396/4, 436/7 |
| 5 | prose | 23/0, 40/2, 9/0 |
| 6 | prose | 41/0, 51/3, 31/0 |
| 7 | prose | 41/0, 51/1, 10/0 |
| 8 | prose | 184/1, 296/4, 183/2 |
| 9 | prose | 298/3, 300/4, 303/1 |

Captures: `/tmp/reply-ste-2026-10-21`, `/tmp/reply-pyramid-2026-10-21`, and
`/tmp/reply-pyramid2-2026-10-21` (temporary).

The limit applied is 20 words per sentence for every reply sentence, the stricter of the two
limits the standard sets, because one linter pass cannot tell an instruction sentence from a
description sentence. Sentence length is the whole residual: 20 of the 22 `STE` hits in the final
run are `sentence_over_limit`, and 6 of the 9 replies carry at least one.

The ordering rule holds on 7 of the 9 replies. Reply 4 opens "Stop writes to the database first",
reply 8 opens "No", and reply 9 opens "the release does not go out tomorrow as scheduled". The two
failures are the ones the table threshold already explains: reply 1 opens with two clauses joined
by a semicolon and defers the choice to its last paragraph, and reply 8 states "No" then spends
three paragraphs before naming the rule that makes the answer general.

## Session-shaped comparison of the two ordering bullets

The one-shot prompts cannot reproduce session drift, so this capture reviews a four-file fixture with
tool calls before it reports. Two variants of the same bullet: A is the ordering rule before it was
named, B is the current rule that names the Pyramid Principle, groups the arguments, and exempts a
one-fact answer. Everything else in `AGENTS.md` is identical between the runs.

Reproduce with `evals/session-capture/run.sh <outdir> 3`, once per variant, swapping the bullet
between runs. The fixture is PR-shaped: a five-step plan, an auth module, a migration with no
downgrade, and a metric that reads a column nothing writes.

| Measure | A, ordering only | B, Pyramid named |
| --- | --- | --- |
| replies | 3 | 3 |
| words | 1,756 | 1,697 |
| `HARD` | 0 | 0 |
| `SLOP` | 0 | 0 |
| `STE` | 18 | 36 |
| `STE` per 100 words | 1.03 | 2.12 |
| sentences over 20 words | 12 | 21 |
| semicolons | 4 | 12 |
| `DECORATOR` | 7 table rows in 1 reply | 7 table rows in 1 reply |

The lead is the same in all six replies: every one opens with the verdict. A opens "Nine gaps
separate this change from a safe release", "this change is not safe to release", "This change cannot
go to release on Thursday". B opens "Release is not safe. Nine defects block it", "four blocking
defects and five lesser ones separate this change from a safe release", "The change is not safe to
release".

The one difference the reader feels is the decisive sentence. In B's second reply the second sentence
names the single blocker that settles the argument, "the rollback the plan promises does not exist",
and the same reply is 807 words. In A the same finding arrives in the second paragraph, and no reply
names a decisive blocker. That sentence is the Pyramid Principle working as intended.

The price is sentence length. B nearly doubled the `STE` density, 1.03 to 2.12 per 100 words, and
tripled the semicolons, because a sentence that says "the decisive blocker is that X" carries two
clauses. Grouping pushes against the 20-word limit the same section sets.

With three replies per variant, none of this is a rate. The stable finding is that the ordering rule
works in both versions once the evidence is in the prompt, and the named version buys a decisive
sentence at a measurable cost in sentence length.

## Result under the Plain register, superseded

Two runs on 2026-10-20, eight replies each, same prompts and model. Run 1 used the Reply Style
before the "does not restate the question" clause; run 2 used it after. Both measured a reply
register without Issue 9, so neither is comparable with the run above.

| Class | Run 1 | Run 2 |
| --- | --- | --- |
| `HARD` | 0 | 0 |
| `SLOP` | 0 | 0 |
| `DECORATOR` | 0 | 0 |
| `SHAPE` `MISSING` | 4 of 8 | 4 of 8 |
| `SHAPE` `SPURIOUS` | 0 of 8 | 0 of 8 |
| `SHAPE` ok | 4 of 8 | 4 of 8 |
| words | 2,419 | 2,124 |

Captured replies: `/tmp/reply-2026-10-20` and `/tmp/reply-2026-10-20b` (temporary).

## Per prompt

| # | needs | words | HARD | SLOP | deco | shape | prompt |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | structure | 320 | 0 | 0 | 0 | MISSING | Summarize the tradeoffs between polling and webhooks |
| 2 | structure | 484 | 0 | 0 | 0 | MISSING | Compare optimistic and pessimistic locking |
| 3 | structure | 434 | 0 | 0 | 0 | MISSING | Review this plan: cache the user profile in Redis |
| 4 | structure | 642 | 0 | 0 | 0 | MISSING | Our deploy failed at the migration step |
| 5 | prose | 35 | 0 | 0 | 0 | ok | What port does Postgres listen on by default |
| 6 | prose | 61 | 0 | 0 | 0 | ok | Which HTTP status code means the request was valid but not permitted |
| 7 | prose | 30 | 0 | 0 | 0 | ok | What is the default port for HTTPS |
| 8 | prose | 224 | 0 | 0 | 0 | ok | Is a 200 response with an error message in the body a good API design |

## Reading

The mechanical classes are clean in both runs: no em-dash, no contraction, no
opener, no closer, no slop term, and no decoration of any kind. That part of the rule
holds without attention.

The "does not restate the question" clause changed nothing measurable. Both runs open
with the answer, as rule 1 already required, so the clause names a failure the model
was not making. It stays because it closes the gap against upstream's wording at no
cost.

The defect is narrow and it is the one the rule permits and the model declines. The
rule allows a table only to compare three or more items, and the four structure
prompts ask for a tradeoff or a comparison. Each got 199 to 517 words of prose in run
2. A reader who wants one attribute across two options has to rebuild the table from
paragraphs. Whether a two-option tradeoff counts as three or more items is the exact
ambiguity the earlier record named, and it is still open: reply 1 compares latency,
cost, firewall traversal, and failure handling, so the compared things number four.

## The conclusion-first rule

The rule added on 2026-10-21 ("Lead with the conclusion") has its own prompt, number 9,
a status report on supplied evidence with a release decision due tomorrow. Ordering is
meaning, so no regex scores it. `--lead` prints each reply's first sentence and the
first sentence of its last paragraph, and the verdict is read against one test: does
the first sentence carry the decision the reader acts on.

Three pairs, one reply each, with the bullet present and absent in `AGENTS.md`. The
first version of the bullet is a fourth reply, kept because it failed.

| Reply | Bullet | First sentence | Verdict |
| --- | --- | --- | --- |
| `/tmp/pyr-with/09.md` | v1 | "the update below is ready to send" | fails, announcement before decision |
| `/tmp/pyr-with-1/09.md` | v2 | "Two blocking defects put tomorrow's release at risk." | passes |
| `/tmp/pyr-with-2/09.md` | v2 | "the release cannot go out tomorrow as scoped: two blocking defects" | passes |
| `/tmp/pyr-without/09.md` | absent | "two findings block tomorrow's release" | passes |
| `/tmp/pyr-without-1/09.md` | absent | "the change cannot ship tomorrow in its reviewed state" | passes |
| `/tmp/pyr-without-2/09.md` | absent | "the change can ship tomorrow only if the two blocking defects are fixed first" | passes |

Mechanically all six are clean: `HARD` 0, `SLOP` 0, `DECORATOR` 0, `SHAPE` ok 6 of 6,
2,042 words.

The rule does not change the outcome on this prompt, because the model already leads
with the decision when the evidence and the question arrive together. The one failure
was caused by the rule's own first wording, which asked for "the reader's terms" and
left an announcement available; naming the announcement as banned cleared it in both
later replies.

The failure the rule exists for is different, and this harness cannot reproduce it.
A real session reply of 2026-10-20 buried the actionable result ("eleven items, four
blocking, one payload edit") in its final two paragraphs after nine paragraphs of
findings. That reply came at the end of a long session with tool calls, so the failure
is drift inside a working session, not a property of a one-shot answer. Measuring it
needs a session-shaped capture: a fixture repository, a scripted sequence of tool
calls, then a request for the status update. That capture does not exist yet, and the
rule stays on the strength of the failure it names until one does.

## Retired from this record

The previous version of this file compared a prose-only rule with a judgment rule
over three runs, scored `DECORATOR` as a defect, and reported `MISSING` falling from
50 percent to 17 percent. That experiment tested a rule that was reverted, and its
`DECORATOR` class scored a structure the current rule permits. Both are gone. The
6,313 words and the three-run design belong to that experiment, not to this one.

## Known limits

**Two runs, one model.** `SHAPE` is the stochastic class; the earlier three-run record
showed the structure prompts disagreeing with themselves across runs. Treat the
`MISSING` count as one sample per run, not a rate. `HARD`, `SLOP`, and `DECORATOR` are
deterministic and need no repetition.

**The `SLOP` class is a lexicon, not a parser.** It catches named terms. It cannot
catch an undefined abstraction such as "asymmetry". Word choice in replies has no
complete automated check in this harness.

**Approved vocabulary is not scored.** The Issue 9 dictionary holds about 900 approved
words and 1,200 rejected words, and ASD does not permit reproduction. `STE` therefore
covers every machine-checkable constraint and misses the one the standard is named
for: an unapproved word reads as clean here.

**The `SHAPE` labels predate the current rule.** They were authored for the judgment
rule, where structure was always permitted. Under the current rule the four structure
prompts sit at the table threshold, so their verdict is a judgement about what counts
as a compared item, not a fact about the reply.

**The vendored linter lints documents, not replies.** `score-replies.py` uses its
`--type reply` reader for counts and its descriptive pass only for the slop word
count, so its sentence-length, modal, and tense rules do not enter the reply score.
