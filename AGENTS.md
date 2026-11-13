# Repository rules

This repository holds configuration. The implementation that acts on it lives in
`~/Research/rice-configuration`. Read that repository's `AGENTS.md` before you write code.

`AGENTS/AGENTS.md` holds the global agent rules. This file holds the rules for this repository and
for the account it configures.

## The boundary

Ask whether an application reads the file as a value, or runs it.

- A value file stays here: `aerospace/aerospace.toml`, `ghostty/config`, `tmux/*.conf`,
  `fish/**`, `nvim/**`, `git/.gitconfig`, `task/.taskrc`, `task/themes/`, `herdr/config.toml`,
  `rex/init.lua`, `pi/settings.json`, `pi/keybindings.json`, `pi/themes/`, `AGENTS/**`.
- Anything that runs lives in `~/Research/rice-configuration/packages/<name>/`: a shell script, a
  TypeScript extension, a Lua service, a launchd plist, a generated theme, an executable shim.
- A theme file is a value and stays here only when nothing generates it. The Rex themes moved,
  because `sync-inkstone.sh` writes them.

## What moved

| Was here | Package there | Installed at |
|---|---|---|
| `sketchybar/` | `packages/sketchybar-bar` | `~/.config/sketchybar/`, 17 links |
| `agent-monitor/` | `packages/agent-monitor` | `~/.local/bin/agent-monitor`, two adapters, `~/.pi/agent/extensions/agent-monitor.ts`, `~/.config/sketchybar/plugins/agent_monitor.sh` |
| `tmux/scripts/` | `packages/tmux-scripts` | `~/.local/bin/tmux-*.sh` |
| `rex/scripts/`, `rex/bin/`, `rex/launchd/` | `packages/rex-services` | `~/.local/bin/golden-ratio`, `~/.local/bin/rex-plannotator-review.sh`, `~/.local/share/rice/rex/*.lua` |
| `rex/themes/` | `packages/rex-themes` | imported into the Rex settings, no link |
| `pi/extensions/` | `packages/pi-extensions` | `~/.pi/agent/extensions/*.ts` |
| `herdr/status-pi-step.sh`, `herdr/plannotator-tui` | `packages/herdr-tools` | `~/.config/herdr/status-pi-step.sh`, `~/.local/bin/plannotator-tui` |
| `bin/` | none, deleted | it held two symlinks whose targets moved, and nothing on PATH named it |

An untracked `.loop-data/` scratch directory can recreate `agent-monitor/` or `sketchybar/` here.
Git tracks no file under those names, so `git ls-files` is the test.

## Configuration names installed paths

A configuration file never names a path inside this repository for something that runs.

- An executable is named as `~/.local/bin/<program>`.
- A file that the application reads keeps the path the application already names:
  `herdr/config.toml:47` calls `~/.config/herdr/status-pi-step.sh`, and
  `packages/sketchybar-bar/files/left.sh` reads `$PLUGIN_DIR/agent_monitor.sh`.
- Do not recreate a shim directory here. Put the executable in `~/.local/bin` and declare the link
  in a rice package.

## Commands

```sh
sh ~/dotfiles/init.sh                                   # this repository's links, then rice apply
~/Research/rice-configuration/bin/rice apply [package]   # create the declared links, run install.sh
~/Research/rice-configuration/bin/rice status [package]  # linked, missing, conflict, or foreign
~/Research/rice-configuration/bin/rice new <name>        # scaffold a package there
sh ~/Research/rice-configuration/tests/migration-check.sh  # the account matches the record
```

`init.sh` is the installer for this repository. A new value file needs a line there, and nothing
else.

## A change that spans both repositories

Edit the code in the rice package and the configuration here, and make the configuration name the
installed path in the same change. Two commits, one per repository. Leave them disagreeing and the
next `rice status` reports a missing or foreign link.

## Open items

- `pi/scripts/todo-cadence.py` is code that still lives here. It belongs in a rice package when
  something calls it.
- `instructions/AGENT_MONITOR_INTEGRATION.md` is stale: it names tmux scripts that never shipped and
  predates the single-sink design.
- `init.sh` links `~/dotfiles/opencode/agent` and `~/dotfiles/gemini/commands`, and neither directory
  exists. Both installed links dangle. Delete the two blocks or restore the directories.
