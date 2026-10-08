# 08 Verify

Phase gate: you cannot leave phase 8 without the artifact below.
Skill: `~/.pi/agent/git/github.com/obra/superpowers/skills/verification-before-completion/SKILL.md`

## Enter

- You are about to claim work is complete, fixed, or passing.
- You are about to commit or open a PR.

## Exit artifact

The command output that proves the claim. Not a summary of the output, and not a recollection of
running it earlier: the output itself.

## Earns its place

- **Prevents:** a success claim with no command output behind it.
- **Evidence:** the skill's own iron law is the measure: "Evidence before claims, always."

## Second opinion available here

`ripwire-change-check --quality-delta` measures your own diff against the baseline, and
`--affected` / `--test-gate` name the tests the change requires. Both are inputs to this phase's
claim, not replacements for the output that backs it.

## Not this card

- This phase is the self-check on your own work. Independent review is phase 9.
- A claim that fails here sends you back, not forward: an unexplained failure is phase 6.

## Handoff

Phase 9 consumes the evidence. A reviewer who is handed claims without output has to re-derive
them, which is the cost this phase exists to remove.
