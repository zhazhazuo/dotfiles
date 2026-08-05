-- Active colorscheme: focus-walker (local, in this config directory).
-- Previously used themes (gruvbox-material, cyberdream, alabaster, catppuccin,
-- bamboo) were removed. Recover them from git history if needed.

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

return {
	focus_walker,
}
