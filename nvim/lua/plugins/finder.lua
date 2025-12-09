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
			"nvim-lua/plenary.nvim", -- For window drawing utilities
			"nvim-telescope/telescope.nvim", -- Optional: for fuzzy search capabilities
			"nvim-treesitter/nvim-treesitter", -- Optional: for showing grammar context
		},
		config = function()
			require("spelunk").setup({
				enable_persist = true,
			})
		end,
	},
}


return {
	snipe,
	spelunk,
	telescope,
}
