---
name: ops-nav
description: Use when the task involves Confluence pages, Plannotator plan or code review, handing a plan, spec, or document to the human for annotation and review in a Herdr pane, pi-loop evidence, anti-slop oxlint plugins, writing documentation in plain or Simplified Technical English, distilling a working document into a state snapshot, grilling a plan or decision, coordinating pi sessions, Herdr panes, browser automation with the agent_browser tool, delegating a quick task to a subagent, preparing or creating a VCN release pull request and resolving its pre-flight codes, or integrating a newly installed skill, tool, or extension into the agent setup.
---

# Ops skills router

Expand `~` to the home directory. Pick one row. Read that file with the read tool, then follow it.

| Task | Skill | File |
|---|---|---|
| Read, search, create, update, move, or export Confluence pages and attachments | confluence | `~/.pi/agent/npm/node_modules/confluence-cli/plugins/confluence/skills/confluence/SKILL.md` |
| Plan review and code or PR review in the browser with Plannotator; annotating files and URLs; Guided Reviews | plannotator | `~/.pi/agent/npm/node_modules/@plannotator/pi-extension/skills/plannotator/SKILL.md` |
| Hand a plan, spec, or design document, or your own last reply, to the human for review in a Herdr pane; read their numbered feedback | plannotator-tui | `~/.agents/skills/plannotator-tui/SKILL.md` |
| pi-loop evidence, status, or refinement routing | pi-loop | `~/Research/pi-psyduck/skills/pi-loop/SKILL.md` |
| Install, configure, update, or migrate vendored anti-slop Oxlint plugins | install-anti-slop | `~/.agents/skills/install-anti-slop/SKILL.md` |
| Transform a working document (SPEC, plan, design) into a clean state snapshot for handoff | distill-context | `~/.agents/skills/distill-context/SKILL.md` |
| Write or rewrite documentation, READMEs, runbooks, error messages, or release notes in plain technical English, or check text against ASD-STE100 | simple-english | `~/.agents/skills/simple-english/SKILL.md` |
| Grill a plan, decision, or idea with relentless questions | grilling | `~/.agents/skills/grilling/SKILL.md` |
| Coordinate with other pi sessions: list, message, ask, reply | pi-intercom | `~/Research/pi-intercom/skills/pi-intercom/SKILL.md` |
| Control Herdr terminal multiplexer panes, tabs, workspaces (needs HERDR_ENV=1) | herdr | `~/.agents/skills/herdr/SKILL.md` |
| Delegate one task to a subagent | pea-shooter | `~/.agents/skills/pea-shooter/SKILL.md` |
| Prepare or create a VCN release pull request; resolve a pre-flight code such as `NO_COMMITS_AHEAD`; complete the release payload from the intake JSON contract | vcn-release | `~/.agents/skills/vcn-release/SKILL.md` |
| Drive browser sessions, page snapshots, click flows, screenshots, or web recording with the native `agent_browser` tool | pi-agent-browser-native | `~/.pi/agent/npm/node_modules/pi-agent-browser-native/README.md` |
| Integrate a newly installed skill, tool, or extension; create or retire navigator groups; sync AGENTS.md | integrate-capability | `~/.agents/skills/integrate-capability/SKILL.md` |

## Notes

- Large output processing goes through `codemode`: one script calls the tools, prints a summary, and
  keeps the raw bytes out of the conversation. Use the `bash` tool inside the script when it needs
  the file system or the network.
