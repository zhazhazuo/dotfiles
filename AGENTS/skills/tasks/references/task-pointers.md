# Task pointers

Four optional attributes say where a task's work is done, so the next agent does not have to
rediscover it. They are user-defined attributes (UDAs) declared in `~/.taskrc`, which is a
symlink to `dotfiles/task/.taskrc` and is tracked in git.

| Field | Label | Holds | Example |
|---|---|---|---|
| `repo` | `Repo` | absolute path of the codebase | `/Users/walkerw/Work/BA/ST/sales-tool-frontend` |
| `branch` | `Branch` | the branch this task is about | `feat/gtm` |
| `doc` | `Doc` | URL of the page that specifies the work | `https://…atlassian.net/wiki/spaces/GTM/pages/123` |
| `ticket` | `Ticket` | issue-tracker key | `GTM-123` |

All four are `type=string` and most tasks have none set. `task <id>` prints them as labelled rows,
`export` carries them, and `task list` does not show them. Read one directly with
`task _get <id>.<field>`.

## Querying a pointer — prefix match, case-sensitive

A string UDA filter matches a **literal prefix**, case-sensitively:

| Filter | Match |
|---|---|
| `repo:/Users` | yes — a prefix |
| `repo:<full value>` | yes — the value is a prefix of itself |
| `repo:<full value>-extra` | no — a superstring is not a prefix |
| `repo:/users` | no — case-sensitive |
| `repo:<full value>/` | no — a trailing slash breaks the match |

One query per axis follows from that, which is the reason for one field per kind rather than one
combined field:

```bash
task repo:/Users/walkerw/Work +PENDING             # everything in this code tree
task doc:https://…atlassian.net/wiki/spaces/GTM/   # everything for this Confluence space
task ticket:GTM-                                   # everything for this Jira project
```

A substring search does not work on a pointer field. `/pattern/` does search, but it reads the
description and annotations, not the pointers.

## The trap: an undeclared field overwrites the description

If the field is not declared in `.taskrc`, `modify` does not fail. It treats the text as
description words and replaces the description: `task 12 modify repo:/path/to/repo` prints
`Modifying task 12 'repo:/path/to/repo'.` then `Modified 1 task.`, exits 0 with no warning, and the
description is gone.

The trap is not specific to pointers: any attribute the configuration does not declare behaves this
way, so an `estimate` written against a taskrc with no `uda.estimate` also lands in the description.
Before writing any pointer, confirm it is declared:

```bash
task show | grep '^uda\.repo\.' || echo 'not declared'
```

Treat a missing declaration as a change to propose to the user, not one to make: the declaration
lives in `.taskrc`, which the skill does not edit on its own initiative.

A declared UDA also needs a `label`, or its value renders in `task <id>` with no name beside it,
indistinguishable from any other value. Every declaration is a `type` line plus a `label` line.

## Verify, then report — never make the repository match the field

The field is what the user intended; the repository is what is true. They diverge routinely. At
pickup, read the pointer and then ask git:

```bash
R=$(task _get 12.repo)
test -d "$R" || echo "recorded repo does not exist"
git -C "$R" rev-parse --abbrev-ref HEAD         # actually checked out
git -C "$R" branch --list "<branch>"            # does the recorded branch exist
git -C "$R" worktree list                       # where that branch lives; stale worktrees
git -C "$R" status --short                      # uncommitted work
```

Report what you find — a missing path, an absent branch, a branch that is not checked out, a
prunable worktree, a dirty tree — and stop there. Do not check out, switch, stash, prune or create
a worktree. Those change the user's working tree and are a separate decision.

Store the pointer and derive the rest. Worktree location, remote URL, divergence from the base
branch, dirty state and staleness are all answers git gives you at pickup time; writing them into
the task only creates a second copy that goes stale.

## Following a pointer

`doc` and `ticket` point at the specification, not at decoration. When a task carries a `doc:`
URL, read that page before proposing work; this environment has Confluence read and search tools.
A `ticket:` key names the issue-tracker item the task belongs to.

## Adding a new pointer kind

Declare it, labelled, beside the other pointers in `dotfiles/task/.taskrc`:

```text
uda.pr.type=string
uda.pr.label=PR
```

Then add its row to the table above. One declared line pair plus one table row, and nothing else
changes. Prefer a new named field over packing several values into one: only the start of a string
is queryable, so a combined field cannot be filtered per axis.
