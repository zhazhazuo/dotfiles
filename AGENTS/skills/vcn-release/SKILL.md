---
name: vcn-release
disable-model-invocation: true
description: Use when preparing or creating a VCN release pull request with the vcn-release CLI, when a pre-flight code such as NO_COMMITS_AHEAD, HEAD_BRANCH_NOT_PUSHED, UNPUSHED_COMMITS, HEAD_EQUALS_BASE, or GH_AUTH_REQUIRED blocks a release, when the release payload must be derived from a branch, or when an agent must complete the intake JSON contract and get operator approval before creating the PR.
---

# VCN release pull request

The CLI owns the policy, the derivation, and the pre-flight. You own the evidence, the two narrative fields, and the approval gate. Do not re-implement window rules, required fields, or date logic.

## Authentication

A `GITHUB_TOKEN` in the shell overrides the login gh keeps in its keyring, and a stale token there fails every gh call with 401 while the stored login still works. When `GH_AUTH_REQUIRED` appears, compare the two states before you report it:

```bash
env -u GITHUB_TOKEN gh auth status   # the stored login
gh auth status                       # the same check under the environment token
```

If the first succeeds and the second fails, the shell token is stale. Run every command below as `env -u GITHUB_TOKEN vcn-release ...`, and tell the operator which token is rejected. Do not ask for `gh auth login` when the stored login already works.

## Two phases, never one turn

Phase A prepares and renders. Phase B creates, and it runs only after the operator approves the rendered content in a later message. Never run the Phase B command in the same turn that first shows the payload or the body.

### Phase A - prepare

1. Run `vcn-release preflight --json` and stop on any `blocking` entry. Give the operator the `hint` text unchanged.
2. Run `vcn-release intake --json --no-gh` and read `payload`, `fieldSources`, `missing`, `preflight`, and `evidence`. The flag skips the GitHub open-PR lookup, which belongs to creation: it costs a network round trip and changes nothing about the payload.
3. Rewrite `payload.description` and `payload.testScope` from `evidence`, then write the payload to a file. Use commit subjects and `changedPaths`. `description` is one sentence: its first sentence becomes `prTitle`, and anything past 100 characters is clipped at a comma or a space and ends in `...`. Put detail in a second sentence, which the body keeps. Make `testScope` a slash-separated list.
4. Fill every field named in `missing` from `evidence` or from operator input. Never invent a ticket key.
5. Render without side effects, from the file that Phase B will reuse:
   `vcn-release create-pr --json-stdin --json --dry-run --no-gh < /tmp/payload.json`.
   Check that `prTitle` does not end with `...`; set `payload.prTitle` or shorten the description, then render again.
6. Show the operator the result: the title, every field with its source, and the rendered body from `prBodyPath`. Then ask for approval of that exact content. Stop and wait.

### Phase B - create

7. After the operator approves, run the same file with `--execute` and no `--dry-run`:
   `vcn-release create-pr --json-stdin --json --execute < /tmp/payload.json`.
8. If the operator asked for a draft, convert the new pull request after creation: `gh pr ready --undo <number>`, taking the number from `prUrl`. The tool has no `--draft` flag, so say that in the approval ask rather than promising one step.
9. Report `ok`, `executed`, `prUrl`, and every `errors[].hint`. Do not report success from stdout alone.

If the operator changes a field, repeat steps 5 and 6 and get approval again. An instruction to "open the PR" before the content was shown is not approval of the content.

If `vcn-release` is not on PATH, run `node <tool-repo>/src/cli.mjs` with the same arguments.

## The execution gate

- `--dry-run` or `--no-gh` renders and stops. This is a preview, and `ok: true` means the body is ready, not that a PR exists.
- `--execute` is the only way to create a pull request.
- Neither flag on a runnable payload returns `ok: false`, `executed: false`, and `[EXECUTE_CONFIRMATION_REQUIRED]` with an `executeCommand`. Read that as: the content is ready and unapproved.
- `executed` in the envelope states whether a side effect happened. Report it.

## Reading intake output

- `payload` is schema-ready. Every field except the narrative ones already carries evidence.
- `fieldSources` explains each value: `branch-name`, `commit`, `commit-prefix`, `commit-subject`, `path-map`, `config`, `flag`, `human`, or `unresolved`. Quote the source when the operator questions a value.
- `missing` lists the fields with no evidence. An empty list is the only state in which preparation may finish unattended.
- `evidence.commits`, `evidence.changedPaths`, `evidence.diffstat`, and `evidence.commitCount` are the whole basis for the narrative fields. Read them before writing.
- `suggestedTitle` is a suggestion built from the commit subjects. The created title comes from `description`, so set the description and do not hand-write a title that repeats the change type.

## Reading the render result

- `prTitle` is the first sentence of `description`, at most 100 characters. Text past that is clipped at the last comma or space and ends in `...`, so a trailing `...` means the description sentence is too long.
- Set `payload.prTitle` when the derived title clips badly. It overrides the description sentence, so the description can keep the detail the title cannot hold.
- `prBodyPath` is the rendered body, written under `.tmp/` in the repository, next to `release-input.json`. Never stage that directory, and add it to `.gitignore` when the repository does not ignore it yet.
- `windowAllowedNow`, `windowLevel`, `requiresSchedule`, `requiresUrgentReason`, and `requiresUrgentApproval` state the policy verdict. Show the level when it is not `allowed`.
- `nextCommand` is the gh equivalent of the render, for a manual fallback.
- `resumeCommand` re-renders from `.tmp/release-input.json`, the copy the tool saved on this run. `executeCommand` is non-null only in the unapproved state and runs that same copy, so it creates exactly the body that was rendered.
- `executed` and `prUrl` answer whether a pull request exists. A preview reports `executed: false` and `prUrl: null`.

## Fields you must not invent

`scheduledDeploymentAt` stays as derived unless the operator states a date or hour. `releaseType` comes from the window policy at the derived time. `urgentReason` and `directorApproval` are the approver's words, copied verbatim, and only when the policy demands them.

## Pre-flight codes

| Code | Cause | Action |
| --- | --- | --- |
| `REPO_NOT_FOUND` | not a git repository | run from the repository root |
| `HEAD_BRANCH_UNKNOWN` | detached HEAD | report the `hint`; the operator creates a branch |
| `HEAD_EQUALS_BASE` | the current branch is the base | report the `hint`; a release branch is needed |
| `BASE_BRANCH_NOT_FOUND` | base missing locally and on origin | report the `hint` |
| `NO_COMMITS_AHEAD` | the branch holds nothing new | the release work is uncommitted; stop and report |
| `NO_GIT_REMOTE` | no remote | report the `hint` |
| `HEAD_BRANCH_NOT_PUSHED` | head missing on the remote | report `git push -u <remote> <branch>` from `hint` |
| `UNPUSHED_COMMITS` | local head ahead of remote head | report the `hint`; a stale PR body is the alternative |
| `GH_NOT_INSTALLED`, `GH_AUTH_REQUIRED` | gh unavailable or logged out | report the `hint`; if the stored login works, a stale `GITHUB_TOKEN` shadows it (see Authentication) |
| `EXECUTE_CONFIRMATION_REQUIRED` | creation attempted without `--execute` | show the body, get approval, then pass `--execute` |
| `MISSING_DERIVED_FIELD` | a required field has no evidence | ask the operator, then pass `--set <field>=<value>` |
| `MISSING_REQUIRED_FIELD` | an urgent release lacks approval text | ask the approver, then pass `--set` |
| `PR_ALREADY_EXISTS` | an open PR exists for the head branch | report its URL as the result; creation succeeded earlier |

## Commands

```bash
vcn-release preflight --json
vcn-release intake --json --no-gh > /tmp/intake.json
node -e 'const j=require("/tmp/intake.json");
  j.payload.description="<one sentence>";
  j.payload.testScope="<list> / <list>";
  process.stdout.write(JSON.stringify(j.payload))' > /tmp/payload.json
vcn-release create-pr --json-stdin --json --dry-run --no-gh < /tmp/payload.json
# show .tmp/pr-body.md and the field sources, then ask. After approval:
vcn-release create-pr --json-stdin --json --execute < /tmp/payload.json
gh pr ready --undo <number>   # only when the operator asked for a draft
```

Prefix each call with `env -u GITHUB_TOKEN` when a stale shell token shadows the stored login.

`intake --no-gh` and `create-pr --dry-run --no-gh` touch neither GitHub nor a remote, so each completes in about one second. A preparation step that takes several seconds usually reached the network, and the `--no-gh` flag is missing.

Add `--set <field>=<value>` to correct one derived value. Add `--date` or `--hour` to move the schedule.

## Never

Never create, commit, push, or reset on the operator's behalf without an approval of the exact content. Never pass `--execute` in the turn that presents the payload. Never pass `--no-preflight` unless the operator says the check is wrong. Never reinterpret `NO_COMMITS_AHEAD` as a tool fault: the branch has nothing new to merge.

## Done when

The operator approved the rendered body, `create-pr --execute --json` returned `ok: true` with `executed: true` and a `prUrl`, and you reported that URL. A preview returning `ok: true` is not done. When a draft was requested, `gh pr view <number> --json isDraft` reports `true` before you call it done.
