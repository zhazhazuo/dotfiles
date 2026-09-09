---
name: ops-nav
description: Use when the task involves Confluence pages, Plannotator plan or code review, the context-mode knowledge base or ctx tools, pi-loop evidence, anti-slop oxlint plugins, distilling a working document into a state snapshot, grilling a plan or decision, coordinating pi sessions, Herdr panes, browser automation with the agent_browser tool, delegating a quick task to a subagent, or integrating a newly installed skill, tool, or extension into the agent setup.
---

# Ops skills router

Expand `~` to the home directory. Pick one row. Read that file with the read tool, then follow it.

| Task | Skill | File |
|---|---|---|
| Read, search, create, update, move, or export Confluence pages and attachments | confluence | `~/.pi/agent/npm/node_modules/confluence-cli/plugins/confluence/skills/confluence/SKILL.md` |
| Plan review, code review, annotating files or URLs, Guided Reviews with Plannotator | plannotator | `~/.pi/agent/npm/node_modules/@plannotator/pi-extension/skills/plannotator/SKILL.md` |
| Large output processing, sandbox execution, knowledge base (ctx_execute, ctx_search, ctx_index) | context-mode | `~/.pi/agent/npm/node_modules/context-mode/skills/context-mode/SKILL.md` |
| pi-loop evidence, status, or refinement routing | pi-loop | `~/Research/pi-psyduck/skills/pi-loop/SKILL.md` |
| Install, configure, update, or migrate vendored anti-slop Oxlint plugins | install-anti-slop | `~/.agents/skills/install-anti-slop/SKILL.md` |
| Transform a working document (SPEC, plan, design) into a clean state snapshot for handoff | distill-context | `~/.agents/skills/distill-context/SKILL.md` |
| Grill a plan, decision, or idea with relentless questions | grilling | `~/.agents/skills/grilling/SKILL.md` |
| Coordinate with other pi sessions: list, message, ask, reply | pi-intercom | `~/Research/pi-intercom/skills/pi-intercom/SKILL.md` |
| Control Herdr terminal multiplexer panes, tabs, workspaces (needs HERDR_ENV=1) | herdr | `~/.agents/skills/herdr/SKILL.md` |
| Delegate one task to a subagent | pea-shooter | `~/.agents/skills/pea-shooter/SKILL.md` |
| Drive browser sessions, page snapshots, click flows, screenshots, or web recording with the native `agent_browser` tool | pi-agent-browser-native | `~/.pi/agent/npm/node_modules/pi-agent-browser-native/README.md` |
| Integrate a newly installed skill, tool, or extension; create or retire navigator groups; sync AGENTS.md | integrate-capability | `~/.agents/skills/integrate-capability/SKILL.md` |

## Notes

- The ctx helper skills (`ctx-doctor`, `ctx-index`, `ctx-search`, `ctx-stats`, `ctx-insight`, `ctx-upgrade`, `ctx-purge`) are command-only: run `/context-mode:<name>` or read `~/.pi/agent/npm/node_modules/context-mode/skills/<name>/SKILL.md`.
