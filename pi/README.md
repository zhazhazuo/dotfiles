# pi configuration

The tracked half of `~/.pi/agent`. Every file here is reached from the pi agent directory by an
absolute symbolic link, so editing the copy in this folder edits the live configuration.

Nothing in this folder is read directly by pi. pi reads `~/.pi/agent/...`, which resolves here.

## What is linked

| In `~/.pi/agent` | Points at |
|---|---|
| `settings.json` | `dotfiles/pi/settings.json` |
| `keybindings.json` | `dotfiles/pi/keybindings.json` |
| `tool-whitelist.json` | `dotfiles/pi/tool-whitelist.json` |
| `themes/` | `dotfiles/pi/themes/` |
| `extensions/skill-guard.ts` | `rice-configuration/packages/pi-extensions/files/extensions/skill-guard.ts` |
| `extensions/hide-tool-declarations.ts` | `rice-configuration/packages/pi-extensions/files/extensions/hide-tool-declarations.ts` |
| `extensions/peer.ts` | `rice-configuration/packages/pi-extensions/files/extensions/peer.ts` |
| `extensions/browser-instruction-broker.ts` | `rice-configuration/packages/pi-extensions/files/extensions/browser-instruction-broker.ts` |
| `extensions/ask-user-attention.ts` | `rice-configuration/packages/pi-extensions/files/extensions/ask-user-attention.ts` |
| `extensions/herdr-pi-step.ts` | `rice-configuration/packages/pi-extensions/files/extensions/herdr-pi-step.ts` |
| `extensions/herdr-subagents-running.ts` | `rice-configuration/packages/pi-extensions/files/extensions/herdr-subagents-running.ts` |
| `extensions/todo-stale-reminder.ts` | `rice-configuration/packages/pi-extensions/files/extensions/todo-stale-reminder.ts` |
| `extensions/agent-monitor.ts` | `rice-configuration/packages/agent-monitor/files/extensions/agent-monitor.ts` |

Eight of the rows above are code and live in the rice monorepo. The other two extensions load from
outside this repository. `extensions/tokenswitch-provider.ts` is a symlink to
`~/Work/Tools/tokenswitch-provider/tokenswitch-provider.ts`. The `extensions` array in
`settings.json` loads `~/.loongsuite-pilot/plugins/pi-coding-agent/index.mjs`, which writes GenAI
JSONL telemetry records and is installed and updated by LoongSuite Pilot, not by this repo.

Two more links in `~/.pi/agent` sit outside this folder and are not managed here:
`AGENTS.md` points at `dotfiles/AGENTS/AGENTS.md`, and every `skills/*` entry points into
`~/.agents/skills`.

`rpiv-todo/config.json` is the live configuration. `~/.config/rpiv-todo` is a symlink to this
folder, which `init.sh` creates, and the `@juicesharp/rpiv-todo` package reads that path. One file
serves both, so no copy can drift.

## Extensions

| Extension | What it does |
|---|---|
| `hide-tool-declarations.ts` | Hides 44 of the 64 declarations but keeps every hidden tool callable. Adds the `hidden_tools` prompt section and the `/tool-whitelist` command. |
| `skill-guard.ts` | Silences third-party package skills except the four navigators named in `settings.json` under `skillGuard.keepVisible`. |
| `peer.ts` | Adds `/peer <session> <task>`, which lists the live pi-intercom roster and passes a task to another pi session. |
| `browser-instruction-broker.ts` | Stops `pi-agent-browser-native` from injecting its ~36 KB browser playbook into every prompt. The playbook moves to the `browser` subagent definition. |
| `ask-user-attention.ts` | Reports "blocked on human" to Herdr while pi waits for a reply to a blocking prompt. Rex needs no bridge of its own: the terminal reads pi's OSC 7501 report, which the questionnaire supplies only once patched — see Patches. |
| `herdr-pi-step.ts` | Shows what the focused pi session is doing in the Herdr tab bar. |
| `herdr-subagents-running.ts` | Reports "subagents running" to Herdr while the root session waits on background threads. |
| `agent-monitor.ts` | Feeds pi lifecycle events to `agent-monitor`, whose sinks are SketchyBar and tmux. The herdr extensions own the herdr tab bar, so each surface has one owner. |
| `todo-stale-reminder.ts` | Reads the todo board from the session branch and appends one line to the request when it has gone stale: ten tool calls since the last board change, with a task still open. Cost is about 30 tokens on a request that has already missed the rule, and nothing when the board is current. Set `PI_TODO_STALE_REMINDER=off` to disable it. |

Three of these cut the prompt. The prompt is the scarce resource: it is re-sent on every model
call and it competes with the conversation for the context window.

## Tool declarations today

`hide-tool-declarations.ts` keeps a whitelist of tool names declared and hides every other
`direct` tool. A hidden tool stays active and callable, so nothing is lost except the model's
awareness of it. Only `direct` tools are hidden: a tool that `tool_search` loads keeps its
`deferred` exposure and stays declared once loaded.

Measured in `agents/domain-wiki` with one method on both sides:

| Measure | No extension | Now |
|---|---|---|
| Declared tools | 64 | 20 |
| Declaration bytes | 47,700 | 17,554 |
| Hidden tools | 0 | 44 |
| Hidden declaration bytes | 0 | 30,146 |
| Prompt sections | 18,398 | 18,061 |
| Fixed prefix per request | 66,098 | 35,615 |

The saving is 30,483 bytes, about 7,620 tokens, on every request. The `<tools>` index in the
prompt also fell from 20 lines to 9. The `hidden_tools` section that replaced that awareness
costs 595 bytes.

One scale note. The session transcript serializes the same 64 tools at 58,425 bytes, about 20
percent more than the in-memory method above. A figure quoted from a session file is not
comparable with a figure quoted from a live run.

### Reaching a hidden tool

A hidden tool is not in the `tool_search` index, because that index only holds `deferred` and
`codemode` tools and these are `direct`. Two paths reach them:

- `run_tool` with `{tool: "<name>", args: {...}}` runs one by name. Always declared.
- A codemode script calls `searchTools("phrase")` to find one, `describeTool(name)` for its
  arguments, then `tools.<name>(args)` to run it.

The `hidden_tools` prompt section names the five domains so the model knows to look.

## Editing the whitelist

The file holds one key:

```json
{
  "keepDeclared": ["read", "bash", "edit", "write", "grep", "find", "ls",
                   "todo", "ask_user_question", "codemode", "tool_search", "run_tool",
                   "agent_types", "agent_spawn", "agent_steer", "agent_wait",
                   "agent_status", "agent_output", "agent_update", "agent_pause",
                   "agent_stop"]
}
```

`/tool-whitelist` opens a checklist of every registered tool and writes this file on each change.
Outside the TUI it prints the current list. `/tool-whitelist reset` restores the default. A hand
edit applies on `/reload` or in a new session.

`run_tool` stays declared whatever the file says, because hiding it would leave every hidden
tool unreachable. A missing or malformed file falls back to the default with one warning.

## Patches

`patches/` holds changes to installed packages that are not ours. They live outside this repo, so
an update replaces them and `patches/apply.sh` applies them again. The script checks each patch
before applying, so a second run changes nothing.

| Patch | Why |
|---|---|
| `rpiv-ask-user-question-blocked.patch` | The questionnaire mounts with `ctx.ui.custom` but passes no `blocked` option, and pi reports `blocked` over OSC 7501 only for a component that declares one. A waiting `ask_user_question` therefore left pi `working`, so a terminal that renders program status — Rex — stayed green while a question waited. The patch adds `blocked: { kind: "question", message: <first question> }` to both mounts, and the Rex adapter turns that report into the red needs-help state. `@juicesharp/rpiv-ask-user-question` 2.15.0 does not carry the change; the fix belongs upstream. |

`agent-monitor/tests/rex-blocked.test.sh` fails when the installed package no longer carries the
patch, and drives a live Rex block through the state to prove the monitor half.

## Other contents

| Path | Purpose |
|---|---|
| `themes/xuanmo.json` | Dark theme selected by `settings.json`. |
| `themes/xuanmo-dimmed.json` | The same palette with the contrast lowered. |
| `scripts/todo-cadence.py` | Measures how often an agent updates its todo list, from the `rpiv-todo-state` entries in session files. It is the check for `todo-stale-reminder.ts`: lower `maxgap` and fewer dirty endings mean the reminder works. |
| `rpiv-todo/config.json` | Settings and prompt guidance for the rpiv-todo package. `~/.config/rpiv-todo` links here. |
| `.loop-data/` | Run and bundle data from the loop tooling. |

## Tests

`extensions/__tests__/` holds colocated tests for four of the six extensions, run with the repo
test command. `hide-tool-declarations.ts` has none. The reader it would cover most usefully is
`readWhitelistFile`: a missing file, a malformed file, and a name in the file that no registered
tool carries.
