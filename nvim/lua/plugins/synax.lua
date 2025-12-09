local surround = { "echasnovski/mini.surround", version = "*" }

local markdown_view = {
	"OXY2DEV/markview.nvim",
	lazy = false,
	config = function()
		local heading = require("markview.presets").headings

		require("markview").setup({
			preview = {
				icon_provider = "devicons",
			},

			markdown = {
				-- headings = heading.simple,
			},
			latex = {
				enable = true,
			},
			preview_ignore = {
				markdown_inline = {
					-- For enabling using "gd" to navigate in the Obsidian.
					"!internal_links",
				},
			},
			experimental = {
				check_rtp_message = false,
			},
		})

		require("markview.extras.checkboxes").setup({
			default = "X",
			remove_style = "disable",
			states = {
				{ " ", "/", "X" },
				{ "<", ">" },
				{ "?", "!", "*" },
				{ '"' },
				{ "l", "b", "i" },
				{ "S", "I" },
				{ "p", "c" },
				{ "f", "k", "w" },
				{ "u", "d" },
			},
		})
	end,
}

local treesitter_parsers = {
	"lua",
	"vim",
	"vimdoc",
	"javascript",
	"typescript",
	"tsx",
	"html",
	"css",
	"scss",
	"vue",
	"svelte",
	"graphql",
	"python",
	"bash",
	"json",
	"yaml",
	"toml",
	"xml",
	"markdown",
	"markdown_inline",
	"latex",
}

local tressistter = {
	"nvim-treesitter/nvim-treesitter",
	version = false, -- last release is way too old and doesn't work on Windows
	build = ":TSUpdate",
	opts = {
		ensure_installed = treesitter_parsers,
		highlight = { enable = true },
		indent = { enable = true },
		textobjects = { enable = true },
		incremental_selection = {
			enable = true,
			keymaps = {
				init_selection = "<C-space>",
				node_incremental = "<C-space>",
				scope_incremental = false,
				node_decremental = "<bs>",
			},
		},
	},
	config = function(_, opts)
		require("nvim-treesitter.configs").setup(opts)
	end,
}

local config = {
	markdown_view,
	tressistter,
	surround,
	{
		"windwp/nvim-ts-autotag",
		event = "VeryLazy",
		opts = {},
	},

	{
		"windwp/nvim-autopairs",
		config = function()
			require("nvim-autopairs").setup()
		end,
	},
}

return config
