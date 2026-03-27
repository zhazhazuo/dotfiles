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

local tressistter = {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		-- Install parsers (no-op if already installed)
		require("nvim-treesitter").install(treesitter_parsers)

		-- Highlighting and indentation via Neovim built-ins + nvim-treesitter queries
		vim.api.nvim_create_autocmd("FileType", {
			callback = function(ev)
				local ok = pcall(vim.treesitter.start, ev.buf)
				if ok then
					vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end
			end,
		})
	end,
}

local config = {
	-- markdown_view,
	render_markdown,
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
