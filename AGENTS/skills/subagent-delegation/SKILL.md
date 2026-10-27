---
name: subagent-delegation
description: Use when spawning a child agent, delegating work to one, or reviewing what a child returned in pi — choosing the spawn path, proving the child's context, reading the agent type's allow list, writing the brief, and verifying the work on disk. Also use for subagent-driven development (SDD), where the main thread plans and reviews and children build.
disable-model-invocation: true
---

# Subagent delegation

SDD means subagent-driven development: the main thread plans and reviews, and child agents build.
These rules bind the thread that spawns. A child does not load this file.

## The spawn path decides the context

A path with a leading slash and no `/root` prefix, for example `/build-t-group`, starts a fresh
child. A bare name forks the caller's conversation, and `/root/task` forks it too. A forked child
answers the inherited thread instead of the task.

Ask what came before the task before you trust a child. A fresh child answers NONE. A forked child
recounts the thread. Stop a forked child on a build task and re-spawn it at an independent root path.

## Read the type's allow list before you delegate

Delegation is a permission, not an instruction. Read the allow list of the type before you order a
child to delegate; a type with no `agent_spawn` stalls on that order. `toolFiltering: allowed` is
pinned in `~/.pi/agent/subagent-manager/settings.json`, so the allow list is the whole inventory.

## The brief

The brief states the measured state, the closed work, the gate command and the definition of done.
It does not restate the plan. A long invented brief makes the child answer the brief.

## Verify the child yourself

Run `git status` and `find` against the paths the task names. Require the gate command with its
output. A success report with no changed file and no output is not evidence.
