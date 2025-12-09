require("config.lspconfig")
require("config.mapping")

vim.diagnostic.config({
	virtual_lines = {
		current_line = true,
	},
})

local opt = vim.opt

-- enable spell check
opt.spell = true
opt.spelloptions = "camel,noplainbuffer"
opt.spellcapcheck = ""
opt.spellfile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add"
opt.spellsuggest = "best,9"
opt.spelllang = { "en", "cjk" }

-- for high performance
opt.lazyredraw = false
opt.hidden = true
opt.updatetime = 300

-- remove the '~' in the empty content.
opt.fillchars = { eob = " " }

-- Sync with system clipborad
opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus"

-- Confirm to save changes before exiting modified buffer
opt.confirm = true

-- highlight the current line
opt.cursorline = true

-- Relative line numbers
opt.number = true
opt.relativenumber = true

opt.tabstop = 2
opt.shiftround = true -- Round indent
opt.shiftwidth = 2 -- Size of an indent

-- True color support
opt.termguicolors = true

opt.pumblend = 10

-- Allow cursor to move where there is no text in visual block mode
opt.virtualedit = "block"

-- Command-line completion mode
opt.wildmode = "longest:full,full"

-- Minimum window width
opt.winminwidth = 5

-- Disable line wrap
opt.wrap = false

opt.smoothscroll = true
opt.foldexpr = "v:lua.require'lazyvim.util'.ui.foldexpr()"
opt.foldmethod = "expr"
opt.foldtext = ""
opt.foldlevelstart = 99

opt.smartcase = true
-- For insert mode to automatically create indent
opt.smartindent = true

-- Enable persistent undo
opt.undofile = true

-- to set the case insensitive in command line
opt.wildignorecase = true
opt.wildmenu = true
-- to set the case insensitive in search line
opt.ignorecase = true
opt.smartcase = true

-- to use space instead of tab
opt["tabstop"] = 2
opt["shiftwidth"] = 2
opt.expandtab = true

-- add the max length to enable LSP.
opt.maxmempattern = 1000000

-- UI

-- Set transparent background
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
vim.api.nvim_set_hl(0, "LineNr", { bg = "none" }) -- Line numbers
vim.api.nvim_set_hl(0, "FoldColumn", { bg = "none" }) -- Folding column
vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" }) -- Gutter (e.g., Git signs)
vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" }) -- ~ lines at the end of the file
vim.api.nvim_set_hl(0, "StatusLine", { bg = "none" }) -- Status line
vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "none" }) -- Inactive status lines
vim.api.nvim_set_hl(0, "VertSplit", { bg = "none" })
vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" }) -- Vertical split borders

-- Improve visual mode selection clarity
-- vim.api.nvim_set_hl(0, "Visual", { bg = "#3b82f6", fg = "#ffffff" })

-- Enable word-wrap for too long line.
-- Enable line wrapping
vim.opt.wrap = true
-- Preserve indentation on wrapped lines
vim.opt.breakindent = true
-- Set breakindent options to shift and show break symbol
vim.opt.breakindentopt = "sbr"

-- For better Diff color
-- Define a function to set diff highlights based on background
local function set_diff_highlights()
	local bg = vim.o.background
	if bg == "dark" then
		vim.api.nvim_set_hl(0, "DiffAdd", { bold = true, fg = "NONE", bg = "#2e4b2e" })
		vim.api.nvim_set_hl(0, "DiffDelete", { bold = true, fg = "NONE", bg = "#4c1e15" })
		vim.api.nvim_set_hl(0, "DiffChange", { bold = true, fg = "NONE", bg = "#45565c" })
		vim.api.nvim_set_hl(0, "DiffText", { bold = true, fg = "NONE", bg = "#996d74" })
	else
		vim.api.nvim_set_hl(0, "DiffAdd", { bold = true, fg = "NONE", bg = "palegreen" })
		vim.api.nvim_set_hl(0, "DiffDelete", { bold = true, fg = "NONE", bg = "tomato" })
		vim.api.nvim_set_hl(0, "DiffChange", { bold = true, fg = "NONE", bg = "lightblue" })
		vim.api.nvim_set_hl(0, "DiffText", { bold = true, fg = "NONE", bg = "lightpink" })
	end
end

-- Create an augroup and autocmd for Colorscheme event
vim.api.nvim_create_augroup("diffcolors", { clear = true })
vim.api.nvim_create_autocmd("Colorscheme", {
	group = "diffcolors",
	pattern = "*",
	callback = set_diff_highlights,
})
