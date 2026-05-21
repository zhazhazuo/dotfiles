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
