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
	cmd = "Telescope",
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
		event = "VeryLazy",
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
	keys = {
		{ "<leader>m", function() require("miniharp").toggle_file() end, desc = "miniharp: toggle file mark" },
		{ "<C-n>", function() require("miniharp").next() end, desc = "miniharp: next file mark" },
		{ "<C-p>", function() require("miniharp").prev() end, desc = "miniharp: prev file mark" },
		{ "<leader>l", function() require("miniharp").show_list() end, desc = "miniharp: list marks" },
	},
	config = function(_, opts)
		require("miniharp").setup(opts)
	end,
}

return {
	-- snipe,
	spelunk,
	telescope,
	file_navigator,
}
