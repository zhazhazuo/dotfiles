# Development

## Setup Steps

1. Open this directory as the active Neovim config.
2. Start Neovim and let `lua/config/lazy.lua` bootstrap Lazy.nvim if needed.
3. Run `:Lazy sync` when plugin specs or `lazy-lock.json` need updating.
4. Run `:MasonInstallAll` to install configured external tools.

## Commands

- install plugins → `:Lazy sync`
- install external tools → `:MasonInstallAll`
- check focus-walker theme strictness → `nvim --headless -u NONE -l scripts/check-focus-walker-strict.lua`
- test → no project-wide automated test command detected

## Env Vars

- none detected

