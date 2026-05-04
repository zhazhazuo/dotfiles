local surround = { "echasnovski/mini.surround", version = "*" }

local render_markdown = {
	"MeanderingProgrammer/render-markdown.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
	---@module 'render-markdown'
	---@type render.md.UserConfig
}

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
}

local treesitter = {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	init = function()
		-- Enable highlighting + indentation per Neovim 0.12 / nvim-treesitter main
		vim.api.nvim_create_autocmd("FileType", {
			callback = function()
				pcall(vim.treesitter.start)
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})

		-- Install missing parsers on startup
		local already = require("nvim-treesitter.config").get_installed()
		local to_install = vim.iter(treesitter_parsers)
			:filter(function(p)
				return not vim.tbl_contains(already, p)
			end)
			:totable()
		if #to_install > 0 then
			require("nvim-treesitter").install(to_install)
		end
	end,
}

local config = {
	-- markdown_view,
	render_markdown,
	treesitter,
	surround,
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		lazy = true,
		opts = {
			textobjects = {
				select = {
					enable = true,
					lookahead = true,
					keymaps = {
						["af"] = "@function.outer",
						["if"] = "@function.inner",
						["ac"] = "@class.outer",
						["ic"] = "@class.inner",
					},
				},
				move = {
					enable = true,
					set_jumps = true,
					goto_next_start = {
						["]f"] = "@function.outer",
						["]c"] = "@class.outer",
					},
					goto_previous_start = {
						["[f"] = "@function.outer",
						["[c"] = "@class.outer",
					},
				},
			},
		},
	},
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
