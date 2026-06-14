# Editor Core

## Responsibility

- Base Neovim behavior, mappings, and autocmds.

## Entry Points

- `lua/config/options.lua` → editor options
- `lua/config/mapping.lua` → key mappings
- `lua/auto_cmds/switch_theme.lua` → autocmd behavior loaded at startup

## Key Files

- `lua/config/options.lua` → core options
- `lua/config/mapping.lua` → mappings
- `lua/auto_cmds/switch_theme.lua` → theme switch autocmds

## Constraints

- Keep startup requires in `init.lua` small and ordered.
- Prefer feature-local plugin mappings inside `lua/plugins/*` when mappings depend on plugins.

## Scope Table

| Layer | Item | Description |
|-------|------|-------------|
| Implementation | `lua/config/options.lua` | editor option defaults |
| Implementation | `lua/config/mapping.lua` | global key mappings |
| Implementation | `lua/auto_cmds/switch_theme.lua` | startup/autocmd behavior |
| Consumer | `init.lua` | requires options and autocmd modules |

