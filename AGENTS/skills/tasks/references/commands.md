# Command recipes

Comments under each command show what it prints on stdout.

## Read

| Intent | Command |
|---|---|
| Today's agenda, by urgency | `task next` |
| All pending, with project / due / urgency | `task list` |
| One task in full: annotations, history, estimate | `task <id>` |
| Valid project names | `task projects` |
| Tags in use | `task tags` |
| Work in progress | `task active` |
| Reference only — browse | `task all`, `task completed`, `task blocked`, `task blocking` |
| Machine-readable | `task <filter> export` (JSON array) |
| Single field | `task _get <id>.<attr>` → e.g. `task _get 12.uuid` |
| How many match | `task <filter> count` |

`task` with no arguments is not an error: the builtin default command is `next`, so bare `task`
runs the agenda report. Prefer spelling the report out.

**Targeting:** an ID is a position in the working set, not an identity. Completing, deleting or
adding a task renumbers the others — `13 14 15` become `12 13 14` the moment one leaves the set.
An ID copied from a listing is valid only until the next change. One read then one write is safe;
across a sequence, re-read the listing or address the task by UUID, which never changes.

A description word matches every task containing it, and `/MVP/` returns the same set as the bare
word — neither form names one task, so never mutate through a text filter.

`task _get 1.id` means "attribute `id` of task 1"; it is not a first-match lookup, and a filter on
the same command line does not narrow it. Read a filtered list with `export` instead.

**Reading reliably:** without a TTY the report columns collapse and descriptions wrap mid-word, which
makes output unscrapable. Pass a width, or read the field directly:

```bash
# WRONG: a report name shadows the command, so this prints the completed report, not JSON
task completed export

# RIGHT: an attribute filter lets export run
task status:completed export          # JSON array of completed tasks
task rc.defaultwidth=200 completed    # readable report instead of wrapped columns
task _get 12.description              # one field, unwrapped
```

This holds for every report name (`completed`, `active`, `next`, `all`): filter by attribute, not by
report.

`count` carries no default filter either, so `task project:GTM count` counts completed and deleted
matches too. Add the status when you mean the working set: `task project:GTM +PENDING count`.

## Create

```bash
task add "Update the CDC form mechanism" project:GTM.CDC estimate:2 \
  due:2026-10-01
# Created task 12.
```

`add` prints the new ID on stdout — read it from there rather than guessing the next number. Set at
least `description`, `project`, `estimate` and `due`; add `priority` and tags only when the user gave
them. A task that needs context at creation time gets it from a follow-up `annotate`, not from a
longer description.

A bare `due:YYYY-MM-DD` lands at 00:00 local on that day; `due:2026-10-01T23:59:59` and `due:eod`
place it at the end of the day instead. Follow the surrounding tasks rather than restyling the list.

## Update

```bash
task 12 modify estimate:0.5 due:2026-10-15                                 # Modified 1 task.
task 12 annotate "2026-10-01: blocked on legal review, chasing Friday"      # Annotated 1 task.
task 12 denotate "blocked on legal"                                        # removes that annotation
task 12 append " — needs FE sign-off"                                      # extends the description
```

Any attribute the user names can be set the same way, and `+tag` / `-tag` add or remove one. Setting
several attributes in one `modify` is one undoable change — fine when the user asked for all of them,
wrong when you are bundling unrequested edits.

An annotation is normally a dated note; `Q:` / `A:` / `D:` are valid but rare in this list.

## Progress

```bash
task 12 start     # records the start time; also prints a nag when more urgent work exists
task active       # confirms it is the started set
task 12 stop
task 12 done      # Completed task 12 '<description>'.
```

`done` is one-way in practice — recovering it needs `undo`. Confirm the user means *finished*, not
*paused* (that is `stop`) or *dropped* (that is `delete`).

## Destructive

Confirmation-gated commands (`delete`, bulk `modify`, `purge`) abort without applying anything,
because the agent has no TTY and confirmation is on. After the user approves, bypass deliberately:

```bash
task rc.confirmation=off 12 delete     # Deleted 1 task.
task rc.confirmation=off undo          # reverts the single most recent change
```

The override prints `Configuration override rc.confirmation=off` on stderr. Bulk filters such as
`task rc.confirmation=off project:GTM +PENDING modify +next` apply to every match at once — list the
matches with the report first, and show the user what will change.

## Ordering

```bash
task 12 modify depends:13    # 12 is now blocked by 13
task blocked                 # tasks waiting on something
task blocking                # tasks other work depends on
```

Accept the numeric ID directly. `task _get 13.uuid` returns the UUID; capture it whenever more than
one change will follow, because the ID is only a position and the UUID is not.

## Review

```bash
task burndown              # weekly burndown (alias)
task history               # monthly history (alias); task ghistory for the grid form
task calendar              # month view with due tasks marked
task +PENDING count        # how many tasks are actually open
```

Use these when the user asks how the week or month is going; they read the same database and change
nothing. Add `rc.defaultwidth=200` when you need to read a wide report without the column wrapping
that a TTY-less run produces.
