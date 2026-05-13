local surround = { "echasnovski/mini.surround", version = "*", event = "VeryLazy" }

local render_markdown = {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = "markdown",
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

local treesitter = {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	event = { "BufReadPost", "BufNewFile" },
	build = ":TSUpdate",
	config = function()
		-- Enable highlighting + indentation per Neovim 0.12 / nvim-treesitter main
		local function start_treesitter(buf)
			if pcall(vim.treesitter.start, buf) then
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end
		end

		vim.api.nvim_create_autocmd("FileType", {
			callback = function(ev)
				start_treesitter(ev.buf)
			end,
		})

		local current = vim.api.nvim_get_current_buf()
		if vim.bo[current].filetype ~= "" then
			start_treesitter(current)
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
		event = "InsertEnter",
		config = function()
			require("nvim-autopairs").setup()
		end,
	},
}

return config
