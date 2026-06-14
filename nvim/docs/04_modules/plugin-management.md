# Plugin Management

## Responsibility

- Lazy.nvim bootstrap and plugin spec loading.

## Entry Points

- `init.lua` → starts config loading
- `lua/config/lazy.lua` → bootstraps Lazy.nvim and imports `plugins`

## Key Files

- `lua/config/lazy.lua` → Lazy.nvim setup
- `lua/plugins/*.lua` → plugin specs grouped by feature area
- `lazy-lock.json` → pinned plugin revisions

## Constraints

- Keep `vim.g.mapleader` and `vim.g.maplocalleader` before Lazy.nvim setup.
- Prefer adding plugin specs under the existing `lua/plugins/*` grouping.

## Scope Table

| Layer | Item | Description |
|-------|------|-------------|
| Implementation | `lua/config/lazy.lua` | bootstraps Lazy.nvim and imports plugin modules |
| Implementation | `lua/plugins/*.lua` | declares plugin specs and plugin-local config |
| Consumer | `init.lua` | requires the Lazy.nvim bootstrap module |

