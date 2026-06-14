# File Index

## Root

- `init.lua` → starts Lazy.nvim config, editor options, and theme autocmds
- `README.md` → repository readme
- `lazy-lock.json` → pinned plugin revisions

## Colors

- `colors/anysphere.vim` → Vim colorscheme file
- `colors/focus-walker.lua` → Lua colorscheme entry

## Lua Config

- `lua/config/lazy.lua` → Lazy.nvim bootstrap and plugin import
- `lua/config/lspconfig.lua` → LSP client capability, server config, and enablement
- `lua/config/options.lua` → core editor options
- `lua/config/mapping.lua` → key mappings

## Lua Plugins

- `lua/plugins/lsp.lua` → LSP, Mason, diagnostics, and code action plugin specs
- `lua/plugins/formatter.lua` → formatter plugin setup
- `lua/plugins/synax.lua` → syntax-related plugin setup
- `lua/plugins/theme.lua` → colorscheme plugin setup
- `lua/plugins/auto-completation.lua` → completion plugin setup
- `lua/plugins/blade.lua` → Blade-specific plugin setup
- `lua/plugins/ui.lua` → UI plugin setup
- `lua/plugins/mini.lua` → mini.nvim plugin setup
- `lua/plugins/motion.lua` → motion/navigation plugin setup
- `lua/plugins/snack.lua` → snacks.nvim plugin setup
- `lua/plugins/file-manager.lua` → file manager plugin setup
- `lua/plugins/project.lua` → project navigation plugin setup
- `lua/plugins/obsidian.lua` → Obsidian plugin setup
- `lua/plugins/git.lua` → Git integration plugin setup
- `lua/plugins/finder.lua` → finder/search plugin setup

## Focus Walker

- `lua/focus-walker/init.lua` → focus-walker colorscheme assembly
- `lua/focus-walker/palette.lua` → focus-walker palette values
- `lua/focus-walker/groups.lua` → focus-walker highlight groups

## Autocmds

- `lua/auto_cmds/switch_theme.lua` → theme switching autocmds

## Scripts

- `scripts/check-focus-walker-strict.lua` → theme validation helper

## Spell

- `spell/en.utf-8.add` → custom spell words
- `spell/en.utf-8.add.spl` → compiled spellfile

