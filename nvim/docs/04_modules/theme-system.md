# Theme System

## Responsibility

- Colorscheme files, focus-walker palette, and highlight group definitions.

## Entry Points

- `colors/focus-walker.lua` → colorscheme entry
- `lua/focus-walker/init.lua` → focus-walker theme assembly
- `lua/plugins/theme.lua` → theme plugin spec

## Key Files

- `lua/focus-walker/init.lua` → theme setup module
- `lua/focus-walker/palette.lua` → palette values
- `lua/focus-walker/groups.lua` → highlight group mappings
- `colors/focus-walker.lua` → colorscheme loader
- `colors/anysphere.vim` → Vimscript colorscheme
- `scripts/check-focus-walker-strict.lua` → validation script

## Constraints

- Keep palette values centralized in `lua/focus-walker/palette.lua`.
- Run the focus-walker strict check after theme changes.

## Scope Table

| Layer | Item | Description |
|-------|------|-------------|
| Implementation | `lua/focus-walker/*.lua` | theme palette and highlight setup |
| Implementation | `colors/*.vim` | Vimscript colorscheme entries |
| Implementation | `colors/*.lua` | Lua colorscheme entries |
| Consumer | `lua/plugins/theme.lua` | loads theme plugins and colorscheme behavior |

