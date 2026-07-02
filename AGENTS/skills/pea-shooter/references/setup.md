# Setup

What the agent and the host need before the first wrapper call. Load
this file only when a prerequisite is missing or has not been
verified.

## `agent` CLI

The wrapper calls a generic `agent` command on `PATH`. The skill
does not bind to a specific agent vendor; the wrapper does. Install
whichever `agent` binary the host environment expects, then
confirm:

```bash
command -v agent
agent --version
```

If the agent requires an API key, export it in the shell that
invokes the wrapper:

```bash
export AGENT_API_KEY=your_api_key_here
```

The wrapper does not read the key itself; the underlying agent CLI
does. Do not pass keys in prompts — see [safety.md](safety.md).

The exact install instructions depend on which `agent` binary the
host is configured for. Common ones:

- macOS, Linux, WSL: the host project's official installer.
- Windows PowerShell: the host project's Windows installer.
- A self-hosted binary: drop it somewhere on `PATH`.

The skill is intentionally silent on which one. Whatever the
project uses is fine, as long as `agent -p --force
--output-format text "<prompt>"` is a working command.

## Wrapper prerequisites

The wrapper itself needs:

- `bash` — the script is `#!/usr/bin/env bash`.
- `git` — used for diff checks, the boundary check, and the
  working-tree precondition.
- `jq` — used to compose the JSON report.
- `timeout` (GNU coreutils or equivalent) — used to bound the
  agent CLI run. The wrapper falls back to running without a
  timeout if `timeout` is not on `PATH`, but that is not a
  recommended configuration.

Confirm each is on `PATH`:

```bash
command -v bash
command -v git
command -v jq
command -v timeout
```

## Optional environment variables

| variable | default | effect |
| --- | --- | --- |
| `AGENT_TIMEOUT_SECONDS` | `900` | per-call timeout applied to the agent CLI invocation. Raise for genuinely large edits; narrow the prompt instead of raising it for vague ones. |

The wrapper reads no other environment variables.

## Working tree

The wrapper refuses to run outside a git working tree. The agent
should be in a working tree before invoking the wrapper:

```bash
git rev-parse --is-inside-work-tree
```

If the project is not yet a git repository, initialise it (or use
a wrapper extension that supports a non-git checkpoint). The
wrapper's boundary check assumes a git working tree, and so does
its generic validation.
