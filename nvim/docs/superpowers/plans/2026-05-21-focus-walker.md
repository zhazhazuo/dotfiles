# Focus Walker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `focus-walker`, a local dark Neovim colorscheme using the HardHacker palette with Alabaster-style sparse highlighting.

**Architecture:** The theme is implemented as a local Lua colorscheme loaded from `colors/focus-walker.lua`. Palette values, setup state, and highlight application live in `lua/focus-walker/` so the theme remains easy to extract into a standalone plugin later. `lua/plugins/theme.lua` switches the active eager theme from the external Alabaster plugin to the local colorscheme.

**Tech Stack:** Neovim Lua, lazy.nvim plugin specs, Tree-sitter highlight groups, Neovim diagnostic and LSP highlight groups.

---

## File Structure

- Create: `colors/focus-walker.lua` → Neovim runtime colorscheme entry point.
- Create: `lua/focus-walker/palette.lua` → HardHacker-derived color constants.
- Create: `lua/focus-walker/groups.lua` → highlight group table generation.
- Create: `lua/focus-walker/init.lua` → setup options and idempotent theme application.
- Modify: `lua/plugins/theme.lua` → load local `focus-walker` instead of external `alabaster.nvim`.

## Task 1: Theme Module Skeleton

**Files:**
- Create: `lua/focus-walker/palette.lua`
- Create: `lua/focus-walker/groups.lua`
- Create: `lua/focus-walker/init.lua`
- Create: `colors/focus-walker.lua`

- [ ] **Step 1: Create the palette module**

Create `lua/focus-walker/palette.lua`:

```lua
local M = {
	bg_darker = "#211e2a",
	bg = "#282433",
	fg = "#eee9fc",
	selection = "#3f3951",
	comment_muted = "#938AAD",
	red = "#e965a5",
	green = "#b1f2a7",
	yellow = "#ebde76",
	blue = "#b1baf4",
	purple = "#e192ef",
	cyan = "#b3f4f3",
	black = "#000000",
	none = "NONE",
}

return M
```

- [ ] **Step 2: Create a minimal groups module**

Create `lua/focus-walker/groups.lua`:

```lua
local palette = require("focus-walker.palette")

local M = {}

function M.setup(opts)
	opts = opts or {}
	local bg = opts.transparent and palette.none or palette.bg
	local comments = opts.dim_comments and palette.comment_muted or palette.yellow

	return {
		Normal = { fg = palette.fg, bg = bg },
		Comment = { fg = comments },
		String = { fg = palette.green },
		Constant = { fg = palette.yellow },
		Number = { link = "Constant" },
		Boolean = { link = "Constant" },
		Float = { link = "Constant" },
		Character = { link = "Constant" },
		Function = { fg = palette.blue },
		Identifier = { fg = palette.fg },
		Statement = { fg = palette.fg },
		Keyword = { fg = palette.fg },
		Conditional = { fg = palette.fg },
		Repeat = { fg = palette.fg },
		Operator = { fg = palette.fg },
		Delimiter = { fg = palette.fg },
		Type = { fg = palette.fg },
		Special = { fg = palette.purple },
	}
end

return M
```

- [ ] **Step 3: Create the theme entry module**

Create `lua/focus-walker/init.lua`:

```lua
local M = {}

local defaults = {
	dim_comments = false,
	transparent = false,
}

M.options = vim.deepcopy(defaults)

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", defaults, opts or {})
end

function M.load()
	vim.opt.termguicolors = true
	vim.opt.background = "dark"

	vim.cmd("highlight clear")
	if vim.fn.exists("syntax_on") == 1 then
		vim.cmd("syntax reset")
	end

	vim.g.colors_name = "focus-walker"

	local groups = require("focus-walker.groups").setup(M.options)
	for group, spec in pairs(groups) do
		vim.api.nvim_set_hl(0, group, spec)
	end
end

return M
```

- [ ] **Step 4: Create the colorscheme loader**

Create `colors/focus-walker.lua`:

```lua
require("focus-walker").load()
```

- [ ] **Step 5: Smoke-test the skeleton**

Run:

```bash
rtk nvim --headless +'set rtp+=.' +'colorscheme focus-walker' +'lua print(vim.g.colors_name)' +qa
```

Expected output contains:

```text
focus-walker
```

- [ ] **Step 6: Commit**

```bash
rtk git add colors/focus-walker.lua lua/focus-walker/palette.lua lua/focus-walker/groups.lua lua/focus-walker/init.lua
rtk git commit -m "feat: add focus walker colorscheme skeleton"
```

## Task 2: Core Editor UI Groups

**Files:**
- Modify: `lua/focus-walker/groups.lua`

- [ ] **Step 1: Expand `groups.lua` with editor UI groups**

Replace the returned table in `lua/focus-walker/groups.lua` with:

```lua
	return {
		Normal = { fg = palette.fg, bg = bg },
		NormalFloat = { fg = palette.fg, bg = palette.bg_darker },
		FloatBorder = { fg = palette.selection, bg = palette.bg_darker },
		Cursor = { fg = palette.bg, bg = palette.fg },
		CursorLine = { bg = palette.selection },
		CursorColumn = { bg = palette.selection },
		ColorColumn = { bg = palette.bg_darker },
		LineNr = { fg = palette.comment_muted, bg = bg },
		CursorLineNr = { fg = palette.yellow, bg = palette.selection },
		SignColumn = { fg = palette.comment_muted, bg = bg },
		EndOfBuffer = { fg = palette.selection, bg = bg },
		NonText = { fg = palette.selection },
		Whitespace = { fg = palette.selection },
		WinSeparator = { fg = palette.selection },
		VertSplit = { link = "WinSeparator" },
		Visual = { bg = palette.selection },
		VisualNOS = { link = "Visual" },
		Search = { fg = palette.bg, bg = palette.yellow, underline = true },
		IncSearch = { fg = palette.bg, bg = palette.purple },
		Substitute = { fg = palette.bg, bg = palette.green },
		MatchParen = { fg = palette.yellow, underline = true },
		Pmenu = { fg = palette.fg, bg = palette.selection },
		PmenuSel = { fg = palette.black, bg = palette.purple },
		PmenuSbar = { bg = palette.selection },
		PmenuThumb = { bg = palette.purple },
		StatusLine = { fg = palette.fg, bg = palette.selection },
		StatusLineNC = { fg = palette.comment_muted, bg = palette.bg_darker },
		TabLine = { fg = palette.fg, bg = palette.bg_darker },
		TabLineFill = { fg = palette.fg, bg = palette.bg_darker },
		TabLineSel = { fg = palette.bg, bg = palette.fg },
		Folded = { fg = comments, bg = palette.bg_darker },
		FoldColumn = { fg = palette.comment_muted, bg = bg },
		Directory = { fg = palette.blue },
		Title = { fg = palette.fg },
		Question = { fg = palette.fg },
		MoreMsg = { fg = palette.green },
		WarningMsg = { fg = palette.yellow },
		ErrorMsg = { fg = palette.red },

		Comment = { fg = comments },
		String = { fg = palette.green },
		Constant = { fg = palette.yellow },
		Number = { link = "Constant" },
		Boolean = { link = "Constant" },
		Float = { link = "Constant" },
		Character = { link = "Constant" },
		Function = { fg = palette.blue },
		Identifier = { fg = palette.fg },
		Statement = { fg = palette.fg },
		Keyword = { fg = palette.fg },
		Conditional = { fg = palette.fg },
		Repeat = { fg = palette.fg },
		Label = { fg = palette.fg },
		Exception = { fg = palette.red },
		Operator = { fg = palette.fg },
		Delimiter = { fg = palette.fg },
		Type = { fg = palette.fg },
		StorageClass = { fg = palette.fg },
		Structure = { fg = palette.fg },
		Typedef = { fg = palette.fg },
		PreProc = { fg = palette.purple },
		Include = { fg = palette.fg },
		Define = { fg = palette.purple },
		Macro = { fg = palette.purple },
		PreCondit = { fg = palette.purple },
		Special = { fg = palette.purple },
		SpecialChar = { fg = palette.yellow },
		SpecialComment = { fg = comments },
		SpecialKey = { fg = palette.selection },
		Tag = { fg = palette.cyan },
		Underlined = { underline = true },
		Todo = { fg = palette.bg, bg = palette.yellow },
		Error = { fg = palette.fg, bg = palette.red },
	}
```

- [ ] **Step 2: Smoke-test UI groups**

Run:

```bash
rtk nvim --headless +'set rtp+=.' +'colorscheme focus-walker' +'lua print(vim.inspect(vim.api.nvim_get_hl(0, { name = "Comment" })))' +qa
```

Expected output contains a `fg` value for the yellow comment color. Neovim prints decimal RGB values, so the exact number may be `15457910` for `#ebde76`.

- [ ] **Step 3: Commit**

```bash
rtk git add lua/focus-walker/groups.lua
rtk git commit -m "feat: add focus walker editor highlights"
```

## Task 3: Tree-sitter, LSP, Diagnostics, Diff, And Plugin Groups

**Files:**
- Modify: `lua/focus-walker/groups.lua`

- [ ] **Step 1: Add sparse semantic highlight groups**

Add these entries to the returned table in `lua/focus-walker/groups.lua` after the base syntax groups:

```lua
		["@comment"] = { link = "Comment" },
		["@string"] = { link = "String" },
		["@string.documentation"] = { link = "String" },
		["@string.escape"] = { fg = palette.yellow },
		["@character"] = { link = "Constant" },
		["@number"] = { link = "Constant" },
		["@number.float"] = { link = "Constant" },
		["@boolean"] = { link = "Constant" },
		["@constant"] = { link = "Constant" },
		["@constant.builtin"] = { link = "Constant" },
		["@constant.macro"] = { fg = palette.purple },
		["@function"] = { link = "Function" },
		["@function.call"] = { link = "Function" },
		["@function.builtin"] = { link = "Function" },
		["@function.macro"] = { fg = palette.purple },
		["@constructor"] = { fg = palette.cyan },
		["@module"] = { fg = palette.cyan },
		["@type.definition"] = { fg = palette.cyan },
		["@variable"] = { fg = palette.fg },
		["@variable.builtin"] = { fg = palette.yellow },
		["@variable.parameter"] = { fg = palette.fg },
		["@property"] = { fg = palette.fg },
		["@field"] = { fg = palette.fg },
		["@keyword"] = { fg = palette.fg },
		["@keyword.function"] = { fg = palette.fg },
		["@keyword.return"] = { fg = palette.fg },
		["@keyword.conditional"] = { fg = palette.fg },
		["@keyword.repeat"] = { fg = palette.fg },
		["@operator"] = { fg = palette.fg },
		["@punctuation.delimiter"] = { fg = palette.fg },
		["@punctuation.bracket"] = { fg = palette.fg },
		["@punctuation.special"] = { fg = palette.fg },
		["@markup.heading"] = { fg = palette.blue },
		["@markup.link"] = { fg = palette.cyan, underline = true },
		["@markup.raw"] = { fg = palette.green },
```

- [ ] **Step 2: Add diagnostics, diff, LSP reference, Mini, and Telescope groups**

Add these entries to the returned table in `lua/focus-walker/groups.lua` after the Tree-sitter groups:

```lua
		DiagnosticError = { fg = palette.red },
		DiagnosticWarn = { fg = palette.yellow },
		DiagnosticInfo = { fg = palette.cyan },
		DiagnosticHint = { fg = palette.cyan },
		DiagnosticOk = { fg = palette.green },
		DiagnosticUnderlineError = { underline = true, sp = palette.red },
		DiagnosticUnderlineWarn = { underline = true, sp = palette.yellow },
		DiagnosticUnderlineInfo = { underline = true, sp = palette.cyan },
		DiagnosticUnderlineHint = { underline = true, sp = palette.cyan },
		DiagnosticUnnecessary = { fg = palette.comment_muted, underline = true, sp = palette.blue },

		DiffAdd = { fg = palette.green },
		DiffAdded = { link = "DiffAdd" },
		DiffDelete = { fg = palette.red },
		DiffRemoved = { link = "DiffDelete" },
		DiffChange = { fg = palette.yellow },
		DiffText = { fg = palette.fg, bg = palette.selection },

		LspReferenceText = { bg = palette.selection },
		LspReferenceRead = { bg = palette.selection },
		LspReferenceWrite = { bg = palette.selection },

		MiniStatuslineModeNormal = { link = "DiffAdd" },
		MiniStatuslineModeVisual = { link = "DiffDelete" },
		MiniStatuslineModeInput = { link = "DiffChange" },
		MiniStatuslineModeInsert = { link = "DiffChange" },
		MiniStatuslineModeCommand = { fg = palette.black, bg = palette.purple },
		MiniStatuslineModeOther = { fg = palette.black, bg = palette.cyan },

		TelescopeNormal = { link = "NormalFloat" },
		TelescopeBorder = { link = "FloatBorder" },
		TelescopePromptNormal = { link = "NormalFloat" },
		TelescopePromptBorder = { link = "FloatBorder" },
		TelescopePromptTitle = { fg = palette.black, bg = palette.green },
		TelescopePreviewTitle = { fg = palette.black, bg = palette.blue },
		TelescopeResultsTitle = { fg = palette.black, bg = palette.purple },
		TelescopeSelection = { bg = palette.selection },
		TelescopeMatching = { fg = palette.yellow },
```

- [ ] **Step 3: Smoke-test semantic groups**

Run:

```bash
rtk nvim --headless +'set rtp+=.' +'colorscheme focus-walker' +'lua print(vim.inspect(vim.api.nvim_get_hl(0, { name = "@keyword" })))' +'lua print(vim.inspect(vim.api.nvim_get_hl(0, { name = "DiagnosticError" })))' +qa
```

Expected:

- `@keyword` has the foreground color for normal text.
- `DiagnosticError` has the foreground color for red.
- No errors are printed.

- [ ] **Step 4: Commit**

```bash
rtk git add lua/focus-walker/groups.lua
rtk git commit -m "feat: add focus walker semantic highlights"
```

## Task 4: Activate Focus Walker In The Existing Theme Config

**Files:**
- Modify: `lua/plugins/theme.lua`

- [ ] **Step 1: Replace the active Alabaster spec with a local Focus Walker spec**

Modify `lua/plugins/theme.lua` so the active theme section becomes:

```lua
local focus_walker = {
	dir = vim.fn.stdpath("config"),
	name = "focus-walker",
	lazy = false,
	priority = 1000,
	config = function()
		require("focus-walker").setup({
			dim_comments = false,
			transparent = false,
		})
		vim.cmd.colorscheme("focus-walker")
	end,
}
```

Keep the other theme specs in the file. Update the returned table to:

```lua
return {
	-- grubox,
	-- best_grubox,
	-- bamboo,
	-- catppuccin,
	-- cyber_dream,
	-- alabaster,
	focus_walker,
}
```

- [ ] **Step 2: Verify Neovim loads through the real config**

Run:

```bash
rtk nvim --headless +'lua print(vim.g.colors_name)' +qa
```

Expected output contains:

```text
focus-walker
```

- [ ] **Step 3: Commit**

```bash
rtk git add lua/plugins/theme.lua
rtk git commit -m "feat: use focus walker theme"
```

## Task 5: Final Verification

**Files:**
- Verify only.

- [ ] **Step 1: Run direct colorscheme smoke test**

Run:

```bash
rtk nvim --headless +'set rtp+=.' +'colorscheme focus-walker' +'lua print(vim.g.colors_name)' +qa
```

Expected output contains:

```text
focus-walker
```

- [ ] **Step 2: Run real config smoke test**

Run:

```bash
rtk nvim --headless +'lua print(vim.g.colors_name)' +qa
```

Expected output contains:

```text
focus-walker
```

- [ ] **Step 3: Inspect key highlight groups**

Run:

```bash
rtk nvim --headless +'colorscheme focus-walker' +'lua for _, name in ipairs({ "Comment", "String", "Constant", "@keyword", "DiagnosticError", "Visual", "PmenuSel" }) do print(name, vim.inspect(vim.api.nvim_get_hl(0, { name = name }))) end' +qa
```

Expected:

- `Comment` uses the yellow color.
- `String` uses the green color.
- `Constant` uses the yellow color.
- `@keyword` uses the normal foreground color.
- `DiagnosticError` uses the red color.
- `Visual` has a background color.
- `PmenuSel` has foreground and background colors.

- [ ] **Step 4: Review git diff**

Run:

```bash
rtk git diff -- colors/focus-walker.lua lua/focus-walker/palette.lua lua/focus-walker/groups.lua lua/focus-walker/init.lua lua/plugins/theme.lua
```

Expected:

- Only Focus Walker files and the active theme switch are changed.
- No unrelated worktree changes are included.
