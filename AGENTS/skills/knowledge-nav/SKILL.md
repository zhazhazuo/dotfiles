---
name: knowledge-nav
description: Use when the task needs repository evidence before reading files or searching a checkout, or when the task involves the repoWiki knowledge base — initializing it, archiving a finished feature into it, refining a missing or weak section, verifying its claims against source code, or writing any file under ./repoWiki/.
---

# Repository knowledge skills router

Expand `~` to the home directory. Pick one row. Read that file with the read tool, then follow it.

| Task | Skill | File |
|---|---|---|
| Answer from repository evidence: structure, file or symbol location, checkout state, behavior | explore-repository | `~/.agents/skills/explore-repository/SKILL.md` |
| Create a repoWiki knowledge base from scratch, or the user approves one | initialize-knowledge-base | `~/.agents/skills/initialize-knowledge-base/SKILL.md` |
| Document a finished feature that `./repoWiki/06_features/` does not hold | archive-knowledge-base | `~/.agents/skills/archive-knowledge-base/SKILL.md` |
| Fill a gap: a feature, module, or code path missing or incomplete in `./repoWiki/` | refine-knowledge-base | `~/.agents/skills/refine-knowledge-base/SKILL.md` |
| Audit repoWiki credibility, coverage, retrieval evidence, or a claim against its cited source | verify-knowledge-base | `~/.agents/skills/verify-knowledge-base/SKILL.md` |
| Write any file under `./repoWiki/`, or check the house rules for knowledge base prose | knowledge-base-writer | `~/.agents/skills/knowledge-base-writer/SKILL.md` |

## Notes

- The six skills are silenced, so they enter the prompt as neither descriptions nor commands. This table is their only route, and `/skill:<name>` still runs one by name.
- `knowledge-base-writer` is not optional for the four repoWiki jobs: read it before writing a file, every time.
- `explore-repository` carries `allowed-tools: Read, Grep` and claims the precedence for repository evidence. A checkout with `./repoWiki/META.md` sends you to that wiki before ripwire.
