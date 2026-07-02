# Safety

What the agent must never do, plus log and version-control rules.
Load once when the skill is first installed; it is not part of
the per-edit loop.

## The agent does not edit files itself

The agent that loaded this skill must not call the underlying
`agent` CLI directly and must not edit target files with its own
file tools while a wrapper call is in progress. Every filesystem
change the agent wants to make goes through `peashooter.sh`. The
wrapper owns the lock file at `.agent-runs/edit.lock` and the
boundary check; both assume the agent is hands-off during the
call.

## The agent does not plan inside the wrapper

Each wrapper call resolves to a single, narrow edit instruction.
The agent that loaded this skill does the planning, the file
selection, the acceptance criteria, and the retry decisions. The
subagent invoked by the wrapper does only what the prompt says.
Do not pass "figure out X and update everything" prompts — see
[prompting.md](prompting.md).

## The agent reads the JSON report first, the log second

The agent must read the wrapper's JSON report before opening the
full log. The log may contain secrets, paths, or agent-specific
output that does not need to be in the agent's working memory.
Open the log only on a non-`success` report or when the report's
reason is genuinely insufficient.

## Log hygiene

The wrapper writes full agent stdout and stderr to
`.agent-runs/<run-id>.log`. These logs can contain:

- file contents the agent CLI read while editing,
- project paths and identifiers,
- occasionally secrets from the agent's environment.

The agent must:

- keep `.agent-runs/` out of version control (see below),
- redact logs before sharing them externally (in chat, in
  bug reports, in commit messages, in PR descriptions),
- never paste a full log into a retry prompt — quote the
  specific error and the file/line instead.

## Secrets in prompts

Do not put API keys, tokens, passwords, or environment-specific
secrets into the edit instruction. The wrapper passes the
instruction verbatim to the agent CLI, and from there into the
subagent's context. If a secret has to be available to the
subagent, set it in the environment and let the underlying
agent CLI consume it from there.

## `.agent-runs/` is not committed

Add to the project's `.gitignore`:

```gitignore
.agent-runs/
```

The directory contains per-run logs, the lock file, the JSON
report copy, and the diff-check log. None of it is source. None
of it belongs in the repository.

## Reset and revert

The agent may need to undo a wrapper call:

- one file changed, change is unwanted — `git checkout -- <file>`
  or `git restore <file>`,
- several files changed, the call was a `validation_failed` —
  `git restore .` to drop the whole change, then re-issue a
  narrower wrapper call,
- the working tree had uncommitted user work — do not reset.
  Inspect the diff, ask the user, and either keep the wanted
  hunks or revert the unwanted ones individually.

Do not use destructive reset commands (`git reset --hard`,
`git clean -fd`) unless the working tree was clean or changes
were checkpointed. The agent cannot tell the difference
between its own work and the user's local edits.
