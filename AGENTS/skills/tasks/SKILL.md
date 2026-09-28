---
name: tasks
description: Use when the task involves the user's Taskwarrior list — capturing a task, updating, rescheduling, annotating, blocking, completing, deleting, or reviewing what he is working on next.
disable-model-invocation: true
---

# Taskwarrior

`task` is installed and reads the user's own configuration, so plain `task` works from any
directory. There is no sync, no server, and no hooks: the list is one SQLite database at
`$HOME/Research/Brain/Artifact/.task/`, tracked in the `Research/Brain` git repo. A task
change therefore never appears in `git diff`.

## Read before you write

```bash
task next        # what is urgent now — the user's normal entry point
task list        # every pending task with project, due date and urgency
task projects    # the valid project names
task <id>        # one task in full, including annotations and modification history
```

Take the numeric ID from a fresh listing and target the task by that ID. Never target a task by
description text or by project alone — those filters also match tasks the user did not mean.

An ID is a position in the working set, not an identity: completing, deleting or adding a task
renumbers the rest, so `13 14 15` become `12 13 14` as soon as one of them leaves. One read
followed by one write is safe; across a longer sequence re-read the listing, or address the task
by its UUID, which never changes.

Without a TTY the report columns collapse and descriptions wrap mid-word, so add `rc.defaultwidth=200`
when you need to read a report, or pull a single field with `task _get <id>.<attr>`.

## Pointers — where the work happens

A task can carry four optional pointer fields, which say where the work is done rather than what
it is: `repo` (the codebase path), `branch`, `doc` (the page that specifies the work) and `ticket`
(issue key). `task <id>` prints them as labelled rows when they are set.

When the user names a codebase, branch, page or ticket, the task is incomplete without it, and
recording it is part of capturing the task — not extra work you did not ask for. The named value
is the one to write; never invent a path or branch that you have not seen. Most tasks carry no
pointers at all, which is normal and is not something to correct.

```bash
task 12 modify repo:/Users/walkerw/Work/BA/ST/sales-tool-frontend branch:feat/gtm
```

Picking a task up means following its pointers before you propose any work:

- `repo` and `branch` — check them against the repository, then report the difference. The two
  diverge routinely.

```bash
R=$(task _get 12.repo)
git -C "$R" rev-parse --abbrev-ref HEAD   # what is actually checked out
git -C "$R" worktree list                # where each branch lives
```

- `doc` and `ticket` — read them. They point at the specification, and this environment has
  Confluence read and search tools. A pointer left unread is context the user already handed you.

A recorded branch that is not the one checked out is normal — report it and let the user decide.
Never check out, switch, stash or create a worktree to make the repository match the field: the
working tree is the user's, and changing it is a separate decision that you ask for.

## Process

1. Read the current state with the commands above before proposing anything, including any
   pointers the task carries.
2. State the exact command you intend to run, in one line, and why.
3. Wait for approval when the change is destructive (delete, purge, bulk modify), when it
   moves a deadline the user set deliberately, or when it records a pointer you worked out
   yourself rather than one the user named in the request.
4. Run one command. Re-read with `task <id>` to confirm the result.
5. Report the ID, the field that changed, and anything you could not set.

## Hard rules

- The list belongs to the user. Never invent a project, tag, deadline or priority, and never
  restructure the list on your own initiative.
- Destructive and bulk commands are confirmation-gated, and the agent has no TTY, so they abort
  without applying anything. Bypass deliberately and only after approval:
  `task rc.confirmation=off <id> delete`.
- `task rc.confirmation=off undo` reverts the single most recent change. Offer it when a change
  was wrong; do not run it on your own initiative.
- Never edit `~/.taskrc`, never purge, and never complete a task the user has not said is done.
- One command per change, so `undo` stays meaningful.

## Progressive disclosure

- `references/data-conventions.md` — the user's project, description-prefix, tag, estimate,
  priority, date and annotation conventions. Read before creating a task or reshaping one.
- `references/commands.md` — the exact command form for each intent. Read before running
  anything you have not run in this session.
- `references/task-pointers.md` — the pointer fields in full: how to query them, the trap that
  destroys a description when a field is not declared, and how to add a new kind. Read before
  writing a pointer.
