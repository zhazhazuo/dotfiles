local grubox = {
	"sainnhe/gruvbox-material",
	lazy = false,
	priority = 1000,
	config = function()
		-- Optionally configure and load the colorscheme
		-- directly inside the plugin declaration.
		vim.g.gruvbox_material_enable_italic = true
		vim.g.gruvbox_material_transparent_background = 2
		vim.g.gruvbox_material_enable_bold = 1
		vim.g.gruvbox_material_float_style = "dim"
		vim.g.gruvbox_material_diagnostic_virtual_text = "highlighted"
		vim.g.gruvbox_material_diagnostic_line_highlight = 1
		vim.g.gruvbox_material_better_performance = 1

		vim.cmd.colorscheme("gruvbox-material")

		vim.cmd([[
			highlight @markup.heading.2.markdown guifg=#F1FA8C gui=bold
			highlight @markup.heading.3.markdown guifg=#8BE9FD gui=bold
			highlight @markup.heading.4.markdown guifg=#50FA7B gui=bold
			highlight @markup.heading.5.markdown guifg=#BD93F9 gui=bold
			highlight @markup.heading.6.markdown guifg=#FF79C6 gui=bold
		]])
	end,
}

local cyber_dream = {
	"scottmckendry/cyberdream.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		require("cyberdream").setup({
			transparent = true,
			italic_comments = true,
			hide_fillchars = true,
			borderless_telescope = true,
			terminal_colors = true,
		})
		vim.cmd.colorscheme("cyberdream")
	end,
}

local alabaster = {
	url = "https://git.sr.ht/~p00f/alabaster.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		vim.cmd.set("termguicolors")
		vim.cmd.colorscheme("alabaster")
		vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", { fg = "#888888", underline = true, sp = "#8ebeec" })

		vim.api.nvim_set_hl(0, "MiniStatuslineModeNormal", { link = "DiffAdd" })
		vim.api.nvim_set_hl(0, "MiniStatuslineModeVisual", { link = "DiffDelete" })
		vim.api.nvim_set_hl(0, "MiniStatuslineModeInput", { link = "DiffChange" })
		vim.api.nvim_set_hl(0, "@function.call", { link = "AlabasterBlue" })
	end,
}

return {
	-- grubox,
	-- cyber_dream,
	alabaster,
}
