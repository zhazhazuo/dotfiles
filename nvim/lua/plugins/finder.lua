local snipe = {
	"leath-dub/snipe.nvim",
	event = "VimEnter",
	keys = {
		{
			"<leader>fn",
			function()
				require("snipe").open_buffer_menu()
			end,
			desc = "Open Snipe buffer menu",
		},
	},
	opts = {},
}

local telescope = {
	"nvim-telescope/telescope.nvim",
	dependencies = {
		{
			"nvim-telescope/telescope-fzf-native.nvim",
			build = "make",
		},
	},
	opts = {
		extensions_list = { "fzf" },
	},
}

local spelunk = {
	{
		"EvWilson/spelunk.nvim",
		dependencies = {
			"folke/snacks.nvim", -- Optional: for enhanced fuzzy search capabilities
			"nvim-treesitter/nvim-treesitter", -- Optional: for showing grammar context
			"nvim-lualine/lualine.nvim",
		},
		config = function()
			require("spelunk").setup({
				enable_persist = true,
			})
		end,
	},
}

local file_navigator = {
	"vieitesss/miniharp.nvim",
	opts = {
		autoload = true,
		autosave = true,
		show_on_autoload = false,
	},
	config = function()
		vim.keymap.set("n", "<leader>m", require("miniharp").toggle_file, { desc = "miniharp: toggle file mark" })
		vim.keymap.set("n", "<C-n>", require("miniharp").next, { desc = "miniharp: next file mark" })
		vim.keymap.set("n", "<C-p>", require("miniharp").prev, { desc = "miniharp: prev file mark" })
		vim.keymap.set("n", "<leader>l", require("miniharp").show_list, { desc = "miniharp: list marks" })
	end,
}

return {
	-- snipe,
	spelunk,
	telescope,
	file_navigator,
}
