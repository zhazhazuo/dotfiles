# 01 Orient

Phase gate: you cannot leave phase 1 without the artifact below.
Skill: `~/.agents/skills/ripwire-router/SKILL.md`

## Enter

- You are about to change code you have not mapped.
- You must answer a question about code: "how does X work", "where is Y".
- You are unsure which ripwire verb fits the moment.

## Exit artifact

A map: for each symbol you will write, the existing symbol to extend or reuse, the seams the
change crosses, and the tests to run. Without it you are guessing at phase 5.

## Earns its place

- **Prevents:** writing a symbol that already exists; reading ten files to learn one fact.
- **Evidence:** measured. The router auto-routes a query that names a symbol to name-exact BM25
  (recall@1 ~99% against ~77% for the generic ranker), so knowing the name and querying it
  verbatim is the cheap path. Cold parse is about 1s at 1500 files, warm after, which is what
  makes chaining rungs nearly free. `--recall` returns the relevant docs' bodies at ~47x fewer
  tokens than loading everything.

## Not this card

- A named symbol is `ripwire-navigate`, not orient.
- Code you did not write, or a subsystem you must size up, is `ripwire-fresh-eyes`.
- Vetting your own diff is `ripwire-change-check`, and it belongs to phase 8.
- A measurement already in hand, deciding which refactor, is `ripwire-quality-bar`.

## Handoff

Phase 5 consumes the reuse candidate. Phase 4 consumes the tests-to-run list.
