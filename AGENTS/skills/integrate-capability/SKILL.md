---
name: integrate-capability
description: Use when a new skill, tool, or extension was installed or added to the pi agent setup and needs classification, silencing, navigator routing, or AGENTS.md sync. Also use when creating, splitting, or retiring a navigator group, or when deciding where an existing capability belongs.
disable-model-invocation: true
---

# Capability integrator

Integrate one new capability into the agent system.

System facts:

- Concrete skills are silent. Navigators route to them. `/skill:name` still runs a silent skill.
- User-owned skills live in `~/.agents/skills` and sync through dotfiles. Package skills live under `~/.pi/agent/npm` or `~/.pi/agent/git` and revert on package update.
- `~/.pi/agent/AGENTS.md` holds the navigator list and the install mandate. It is the registry, not a table copy.
- Navigators are visible by design. The group list is data, not a constant.

## Flow

1. Identify what arrived: skill files, extension tools, or a package. Record absolute paths.
2. Classify the purpose into a domain (code, design, ops, or a new domain).
3. Apply the visibility rule.
4. Add one routing row to the matching navigator.
5. Sync `AGENTS.md`.
6. Verify.

## Visibility rule

- User-owned concrete skill: add `disable-model-invocation: true` to its frontmatter. It stays runnable through `/skill:name`.
- Package-owned concrete skill: use the settings filter (`"skills": [...]`) when full removal is acceptable. A frontmatter patch inside a package reverts on package update; re-apply it after updates.
- Extension tools: nothing to silence. Decide scope: repo-specific extensions go to that repo's `.pi/settings.json`; general extensions stay global.
- Navigator skills: never silenced.

## Classify and expand groups

- Compare the purpose against the navigators listed in `AGENTS.md`.
- One navigator fits: add one row to its table. Format: `| Task triggers | skill-name | absolute file path |`.
- No navigator fits: create one.
  1. Name it `<domain>-nav`.
  2. Write its `SKILL.md`: frontmatter description starts with `Use when` and lists concrete triggers; a routing table; notes for command-only skills.
  3. Move existing rows that match the new domain from their current navigators.
  4. Register the navigator in the `AGENTS.md` Skill routing section.
- Split a navigator when its table passes 15 rows.
- Retire a navigator when its table empties: remove it from `AGENTS.md` and delete the folder.

## AGENTS.md sync

- Keep the Skill routing section current: one line per navigator with its domain keywords.
- The install mandate points to this skill. Keep that line unchanged.
- Do not copy navigator tables into `AGENTS.md`.

## Verify

- Expand `~` to the home directory. Confirm every routed path exists.
- Frontmatter: `name` equals the folder name. Description starts with `Use when`.
- After any settings edit: the JSON parses.
- After a navigator change: start a fresh session and check the prompt lists the navigator set.

## Constraints

- A new concrete skill is never visible by default.
- One row per capability. Do not repeat guidance across navigators.
- `AGENTS.md` stays short: navigator list and mandates only.
