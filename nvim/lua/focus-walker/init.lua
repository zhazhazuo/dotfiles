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
