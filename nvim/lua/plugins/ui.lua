local zen_mode = {
	"folke/zen-mode.nvim",
	opts = {
		window = {
			backdrop = 0, -- fully transparent backdrop
			options = {
				signcolumn = "no",
				foldcolumn = "0",
				list = false,
			},
		},
		plugins = {
			options = {
				enabled = true,
				ruler = false,
				showcmd = false,
        laststatus = 3
			},
		},
	},
}

local web_icons = { "nvim-tree/nvim-web-devicons", opts = {} }

local which_keys = {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
		preset = "modern",
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},
	},
}

local bqf = {
	"kevinhwang91/nvim-bqf",
	config = function()
		require("bqf").setup()
	end,
}

local neoscroll = {
	"karb94/neoscroll.nvim",
	event = "BufEnter",
	config = function()
		require("neoscroll").setup({})
	end,
}

local mini_statusline = {
	"echasnovski/mini.statusline",
	version = "*",
	config = function()
		require("mini.statusline").setup()
	end,
}

local statusline = {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		require("lualine").setup()
	end,
}

local noice = {
	{
		"folke/noice.nvim",
		event = "VimEnter",
		opts = {
			cmdline = {
				view = "cmdline",
			},
			lsp = {
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
				signature = {
					enabled = true,
				},
				hover = {
					enabled = true,
				},
			},
			routes = {
				{
					filter = {
						event = "msg_show",
						any = {
							{ find = "%d+L, %d+B" },
							{ find = "; after #%d+" },
							{ find = "; before #%d+" },
						},
					},
					view = "mini",
				},
			},
			presets = {
				bottom_search = true,
				-- command_palette = true,
				long_message_to_split = true,
				-- inc_rename = false, -- enables an input dialog for inc-rename.nvim
				long_message_to_split = true,
				lsp_doc_border = true,
			},
		},
	},
}

return {
	web_icons,
	which_keys,
	bqf,
	-- statusline,
	zen_mode,
	mini_statusline,
	noice,
	neoscroll,
}
