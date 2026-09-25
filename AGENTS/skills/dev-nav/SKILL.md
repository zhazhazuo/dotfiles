---
name: dev-nav
description: Use when the task involves ripwire development flows, writing or changing code, debugging or a failing test, test-driven development, code review or refactoring, naming code for search, structuring React or Vue components, deriving QA test scenarios from a PRD, spec, or bug report, checking alignment on decisions before finalizing, verifying work before claiming done, or writing or editing skills.
---

# Dev skills router

Expand `~` to the home directory. Pick one row. Read that file with the read tool, then follow it.

| Task | Skill | File |
|---|---|---|
| Code navigation, impact, reuse check, quality bar, "how does X work" | ripwire-router | `~/.agents/skills/ripwire-router/SKILL.md` |
| Bug, test failure, or unexpected behavior | systematic-debugging | `~/.pi/agent/git/github.com/obra/superpowers/skills/systematic-debugging/SKILL.md` |
| Implementing any feature or bugfix, before writing implementation code | test-driven-development | `~/.pi/agent/git/github.com/obra/superpowers/skills/test-driven-development/SKILL.md` |
| Before claiming done, fixed, or passing | verification-before-completion | `~/.pi/agent/git/github.com/obra/superpowers/skills/verification-before-completion/SKILL.md` |
| Completing tasks, major features, or before merging — dispatch a code reviewer subagent | requesting-code-review | `~/.pi/agent/git/github.com/obra/superpowers/skills/requesting-code-review/SKILL.md` |
| Receiving code review feedback, before implementing suggestions | receiving-code-review | `~/.pi/agent/git/github.com/obra/superpowers/skills/receiving-code-review/SKILL.md` |
| Naming functions, types, files, or writing code that agents can find by search | write-discoverable-code | `~/.agents/skills/write-discoverable-code/SKILL.md` |
| React or Vue component mixes render with state or logic; structure review | structuring-ui-components | `~/.agents/skills/structuring-ui-components/SKILL.md` |
| Derive QA test scenarios from a PRD, proposal, or bug description | context-to-qa-scenarios | `~/.agents/skills/context-to-qa-scenarios/SKILL.md` |
| A repo is full of low-signal unit tests; delete tests that would not catch a real bug the E2E suite misses, convert their intent to E2E, fan the work out across subagents | prune-low-signal-tests | `~/.agents/skills/prune-low-signal-tests/SKILL.md` |
| Verify agent and user agree on decisions before finalizing a document or implementation | alignment-quiz | `~/.agents/skills/alignment-quiz/SKILL.md` |
| An endpoint does not exist yet, or a backend state (empty/error/duplicate) is needed for local dev or review — mock server, stub API, fixture data | api-mock | `~/.agents/skills/api-mock/SKILL.md` |
| Creating new skills, editing existing skills, or verifying skills work before deployment | writing-skills | `~/.pi/agent/git/github.com/obra/superpowers/skills/writing-skills/SKILL.md` |

## Notes

- The other ripwire skills (`ripwire-orient`, `ripwire-navigate`, `ripwire-change-check`, and so on) live under `~/.agents/skills/ripwire-*/SKILL.md`; route through `ripwire-router` first.
- Delegation alternative `council-mode`: `~/.pi/agent/npm/node_modules/pi-subagents/skills/council-mode/SKILL.md`.
- Plan/execution flows (brainstorming, writing-plans, executing-plans, worktrees, branch finishing, parallel agents) route through `dev-flow-nav`.
- The superpowers skills are package-owned (`git:github.com/obra/superpowers`) and silenced via `disable-model-invocation: true`; that patch reverts on package update — re-apply command is in `dev-flow-nav` notes.
