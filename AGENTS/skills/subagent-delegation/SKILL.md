---
name: subagent-delegation
description: Use when spawning a child agent, delegating work to one, or reviewing what a child returned in pi — choosing the spawn path, proving the child's context, reading the agent type's allow list, writing the brief, and verifying the work on disk.
disable-model-invocation: true
---

# Subagent delegation

These rules bind the thread that spawns. A child does not load this file. For role-specific briefs,
execution handoffs, and supervision, read `~/.agents/skills/subagent-driven-development/SKILL.md`.

## The spawn path decides the context

A path with a leading slash and no `/root` prefix, for example `/build-t-group`, starts a fresh
child. A bare name forks the caller's conversation, and `/root/task` forks it too. A forked child
answers the inherited thread instead of the task.

Ask what came before the task before you trust a child. A fresh child answers NONE. A forked child
recounts the thread. Stop a forked child on a build task and re-spawn it at an independent root path.

## Read the type's allow list before you order sub-delegation

Delegation is a permission, not an instruction. Read the allow list of the type before you order a
child to delegate. A type with no `agent_spawn` stalls on that order. This rule binds sub-delegation,
not an ordinary child that only uses repository tools. `toolFiltering: allowed` is
pinned in `~/.pi/agent/subagent-manager/settings.json`, so the allow list is the whole inventory.

## The brief

For implementation, the brief states the measured state, the closed work, the gate command, and the
definition of done. It does not restate the plan. A long invented brief makes the child answer the brief.
For a coder, keep the spawn prompt short and point to the full execution handoff.

## Inspect the child yourself

After completion, collect the final answer with `agent_output`. Use `agent_status` for live state and
recent output.

For a file-changing task, run `git status` and `find` against the named paths. Run the acceptance
commands and record their output. Record the collection and inspection results in the parent task record.

Researchers and reviewers need no file artifact. Require the citations, paths, findings, and unresolved
facts that the role brief names. A success report without the required role evidence is not evidence.
