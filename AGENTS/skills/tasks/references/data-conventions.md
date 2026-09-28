# Data conventions

Observed patterns, not schema: re-read the database before relying on a current-state claim.

## Configuration

| Item | Value |
|---|---|
| Binary | `/opt/homebrew/bin/task`, v3.5.0 — re-verify behaviour after an upgrade |
| Config | `~/.taskrc` → symlink to `~/dotfiles/task/.taskrc` (edit the dotfiles copy, never `~/.taskrc` directly) |
| Data | `data.location=$HOME/Research/Brain/Artifact/.task`, a `taskchampion.sqlite3` file |
| Tracked in git | yes, in the `Research/Brain` repo — so never treat `git diff` as the task audit trail |
| Sync / hooks | none configured |
| Dates | `dateformat Y-M-D`, `weekstart sunday`, timezone UTC+8 — builtin defaults, not written down |
| Confirmation | on, a builtin default; this is why agent delete and bulk-modify commands need `rc.confirmation=off` |
| Default command | `next`, builtin — bare `task` runs the `next` report, it is not an error |
| Actually set in `.taskrc` | `data.location`, `news.version`, `color=on`, the `estimate` UDA and the four pointer UDAs; everything else is stock Taskwarrior |
| Aliases | `rm`→delete, `history`→history.monthly, `ghistory`→ghistory.monthly, `burndown`→burndown.weekly |

## Projects

Dot-separated hierarchy, `Area.SubArea`. Most of the project list is stale — many names are
leftovers from completed work — so do not read it as a map of what the user is currently doing.

- Always read `task projects` before naming one, and reuse the closest existing name.
- A pending task may legitimately have no project. Do not force one on.

Drift to leave alone unless the user asks:

- `AIHarness:DevelopAgent` uses a **colon**, and it is live on a pending task. The sibling form
  `AIHarness.DevelopAgent` also exists. Do not add new colon names; do not rename the existing one.
- `GTM:AIReportGeneration` and `GTM.AIReportGeneration` are the same project in both forms.

## Description

Descriptions are plain, short and unprefixed. Sentence case, no trailing period.

The `PREFIX:` form (`RD:`, `FEAT:`, `PLAN:`, `MEETING:`, `REVIEW:`, `BUG:`, `POC:`) is a
**historical** convention, present only on completed tasks. Default to plain text; use a prefix only
when the user asks for one, or when extending a line that already carries one. Never add one to a
task that does not have it. There is no `RELEASE:` prefix: `RELEASE` and `Release PoC version` are
literal descriptions.

`task <id> append " more"` extends the description in place; prefer `modify description "..."` when
the title itself was wrong.

## Tags

No pending task carries a tag. Existing tag names across the database are mixed-case and
inconsistent; lowercase appears only in the newer names, so prefer lowercase if a tag is genuinely
needed.

Add a tag only when the user names one. Do not retro-tag existing tasks.

`next` is a Taskwarrior builtin special tag, not a local convention: it carries urgency `+15.0`
(`urgency.user.tag.next.coefficient`), so `+next` is the way to pull one task to the top of the
`next` report for today. Add it with `modify +next`, drop it with `modify -next`.

## Estimate

The `estimate` UDA — one of five fields declared in `.taskrc`; the other four are the pointers
described in `task-pointers.md`. Configured value list `0.5, 1, 1.5, 2, 2.5, 3`, default `1`.

Taskwarrior does **not** enforce the list — `estimate:9` is accepted — so the list is a convention you
have to hold yourself. The unit is not recorded anywhere in the configuration: treat `1` as the user's
baseline for one task, do not explain or convert it, and ask the user for the estimate rather than
guessing.

## Priority

Historical, and not part of the current working set. Do not add a priority to make a task look
important; `+next` is the tool for "today" and `due` is the tool for "when".

If the user asks for one, the accepted values are `H`, `M`, `L`. Anything else is rejected silently
— no error, exit 0, and the field keeps its previous value — so read the task back to confirm a
priority actually landed.

## Dates

| Field | Meaning | Set by |
|---|---|---|
| `due:` | the deadline | `modify due:YYYY-MM-DD` |
| `scheduled:` | when the user plans to start | `modify scheduled:YYYY-MM-DD` |
| `wait:` | hidden from reports until this date | `modify wait:YYYY-MM-DD` |
| `start` | actively in progress; drives the `active` report | `task <id> start` / `stop` |

A bare `YYYY-MM-DD` lands at **00:00 local on that day** — the start of the day, not the end. To
place a deadline at the close of the day instead, pass a time (`due:2026-10-01T23:59:59`) or the
keyword `due:eod` for today. Follow whichever form the surrounding tasks use rather than restyling
the list.

Negative counts in a report (`-7d`) mean the date has passed.

## Annotations

The dominant form is a dated note, either `YYYY-MM-DD: <what happened>` or a plain sentence:

```text
2026-06-18: Suggestion logic pulled back into POC scope.
Meeting booked. Presentation prepared.
```

`Q:` / `A:` / `D:` are a real but occasional convention, not the default. Add an annotation as a
dated note; use `Q:` / `A:` / `D:` only when the text genuinely is a question, an answer, or a
decision.

Keep an annotation to one line. Add with `task <id> annotate "..."`, remove a wrong one with
`task <id> denotate <pattern>`.

## Dependencies

`task <id> modify depends:<other-id>` records that one task blocks another, and a blocked task leaves
the `next` report, which is the point. Use it only for real ordering, never for grouping related work
— use a project or tag for that. Inspect with `task blocked` and `task blocking`.
