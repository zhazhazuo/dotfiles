return {
	{
		"echasnovski/mini.nvim",
		event = "VeryLazy",
		config = function()
			require("mini.icons").setup()

			local hipatterns = require("mini.hipatterns")
			hipatterns.setup({
				highlighters = {
					hex_color = hipatterns.gen_highlighter.hex_color(),
				},
			})
		end,
	},
}
