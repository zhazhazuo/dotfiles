# Focus Walker Colorscheme Design

## Goal

Build `focus-walker`, a personal dark Neovim colorscheme that uses the HardHacker palette but follows Alabaster's minimal highlighting philosophy.

The theme should make code easier to scan by coloring only a small set of meaningful categories. It should not color every keyword, operator, statement, identifier, or type just because a parser can identify them.

## Scope

- Create a local colorscheme inside this Neovim config.
- Target dark mode only.
- Use Lua for the implementation.
- Keep the structure simple enough for dotfiles, but organized so it can later be extracted into a standalone plugin.
- Do not fork or vendor `alabaster.nvim`.
- Do not modify unrelated plugin or editor behavior.

## Visual Direction

Use the HardHacker palette as the color source:

- Background: `#282433`
- Darker background: `#211e2a`
- Foreground: `#eee9fc`
- Selection: `#3f3951`
- Muted comment fallback: `#938AAD`
- Red: `#e965a5`
- Green: `#b1f2a7`
- Yellow: `#ebde76`
- Blue: `#b1baf4`
- Purple: `#e192ef`
- Cyan: `#b3f4f3`
- Black: `#000000`

The theme should feel dark, quiet, and readable. Accent colors should stand out because they are used sparingly, not because every token competes for attention.

## Highlighting Rules

Follow the Alabaster rule set:

- Comments are important and should be prominent.
- Strings are highlighted.
- Statically known constants are highlighted.
- Meaningful global definitions are highlighted.
- Ordinary language keywords stay plain.
- Font variations are avoided.

Default syntax mapping:

- `Normal` text: foreground on background.
- Comments: yellow by default.
- Optional dim comments mode: muted comment color.
- Strings: green.
- Numbers, booleans, floats, characters, enum-like constants: yellow.
- Global definitions, functions, and important symbols: blue or cyan.
- Preprocessor or macro-like constants: purple only when useful.
- Operators, delimiters, and ordinary keywords: foreground.
- No bold or italic for syntax groups.

Tree-sitter and LSP semantic tokens should follow the same sparse rules. If a token category is noisy or unreliable, it should fall back to `Normal`.

## UI Coverage

The theme should include practical editor UI groups:

- Cursor, cursor line, line numbers, color column.
- Visual selection and search matches.
- Popup menu and completion selection.
- Window separators and floating borders.
- Statusline-compatible base groups.
- Diff groups.
- Diagnostic groups and underlines.
- LSP references.

Plugin-specific coverage can be small and focused. Telescope and common Neovim UI groups are enough for the first version. Broader plugin theming can be added only when it improves day-to-day use.

## Configuration

Expose a small setup surface:

- `dim_comments`: default `false`.
- `transparent`: default `false`, if straightforward in the existing config.

The colorscheme should work with:

```lua
vim.cmd.colorscheme("focus-walker")
```

If a setup function is added, it should be optional and have sensible defaults.

## Architecture

Recommended local structure:

- `colors/focus-walker.lua` loads the colorscheme.
- `lua/focus-walker/palette.lua` owns color values.
- `lua/focus-walker/groups.lua` owns highlight group definitions.
- `lua/focus-walker/init.lua` exposes setup and apply functions if needed.

If the existing config strongly favors a single-file theme, the implementation may start with only `colors/focus-walker.lua`, but palette and group boundaries should remain clear inside the file.

## Error Handling

- If `termguicolors` is not enabled, enable it or document that the theme requires it.
- Highlight application should be idempotent so reloading the colorscheme does not accumulate state.
- Missing optional plugins should not produce errors.
- Unknown config keys should be ignored unless the existing config has a validation pattern.

## Testing And Verification

Verify the theme by opening Neovim with the colorscheme loaded and checking:

- `:colorscheme focus-walker` succeeds.
- Comments are yellow by default.
- Keywords remain mostly foreground.
- Strings are green.
- Constants and numbers are yellow.
- Diagnostics, search, visual selection, floating windows, and popup menus remain readable.
- Existing theme/plugin configuration is not broken.

If the repo has an existing Lua style or test command for Neovim config, use it. Otherwise use a headless Neovim smoke test.

## Out Of Scope

- A public plugin release.
- Light mode.
- Full per-plugin theme coverage.
- Recreating every HardHacker highlight group.
- Recreating every Alabaster query or language-specific rule in the first version.
