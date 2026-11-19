---
name: agent-nav
description: Use when the task changes the agent setup itself rather than a project — adding, routing, silencing, splitting or retiring a skill or navigator, writing a skill file, improving a skill on evidence, changing a subagent type or extension, syncing AGENTS.md, or recording the session work unit under ./.ai-artifacts/progress/.
---

# Agent setup skills router

Expand `~` to the home directory. Pick one row. Read that file with the read tool, then follow it.

| Task | Skill | File |
|---|---|---|
| Install, classify, route, silence, split or retire a capability; sync `AGENTS.md` | integrate-capability | `~/.agents/skills/integrate-capability/SKILL.md` |
| Improve a skill on evidence: one frozen iteration round, one edit, a verdict | iterate-skill | `~/.agents/skills/iterate-skill/SKILL.md` |
| Write or revise a skill file: frontmatter, triggers, disclosure, verification | author-high-quality-skills | `~/.agents/skills/author-high-quality-skills/SKILL.md` |
| Record, update or archive the session work unit under `./.ai-artifacts/progress/` | progress-tracking | `~/.agents/skills/progress-tracking/SKILL.md` |

## Where the setup lives

- Skills: `~/dotfiles/AGENTS/skills/<name>/SKILL.md`, linked into `~/.agents/skills/` by `init.sh`.
- Navigators: registered in the `Skill routing` section of `~/dotfiles/AGENTS/AGENTS.md`.
- Subagent types: `~/dotfiles/pi/subagent-manager/agents/<type>.md` and `settings.json`. They are
  copied, not linked, because the subagent manager refuses a symlinked path.
- Extensions: `~/.pi/agent/extensions/*.ts`, owned by the rice package `pi-extensions`.
  `skill-guard.ts` enforces which package skills stay visible.
- Settings: `~/dotfiles/pi/settings.json` is copied to `~/.pi/agent/`, then a host overlay merges
  over it. Edit the repository copy and run `init.sh`.

## Notes

- A navigator is a table with one row per capability. Do not repeat guidance across navigators.
- Split a navigator when its table passes 15 rows. Retire it when the table empties.
- Change a skill by measuring it: `iterate-skill` and `~/.agents/skills/_harness/`. A skill edit
  with no before-and-after number is a rewrite.
- Spawning and delegating work is `dev-flow-nav`. Tools, documents, panes and releases are
  `ops-nav`. This table is only the agent's own files.
