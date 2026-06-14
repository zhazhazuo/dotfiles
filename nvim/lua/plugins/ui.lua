local zen_mode = {
	"folke/zen-mode.nvim",
	cmd = { "ZenMode", "MarkdownWritingMode" },
	config = function()
		require("zen-mode").setup({
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
					laststatus = 3,
				},
			},
		})

		local win_opts = {
			"number",
			"relativenumber",
			"cursorline",
			"colorcolumn",
			"wrap",
			"linebreak",
			"breakindent",
			"breakindentopt",
			"showbreak",
			"spell",
		}
		local buf_opts = {}

		local function save_state(buf, win)
			local state = { win = {}, buf = {} }

			for _, name in ipairs(win_opts) do
				state.win[name] = vim.api.nvim_get_option_value(name, { win = win })
			end

			for _, name in ipairs(buf_opts) do
				state.buf[name] = vim.api.nvim_get_option_value(name, { buf = buf })
			end

			return state
		end

		local function restore_state(buf, win, state)
			for name, value in pairs(state.win or {}) do
				vim.api.nvim_set_option_value(name, value, { win = win })
			end

			for name, value in pairs(state.buf or {}) do
				vim.api.nvim_set_option_value(name, value, { buf = buf })
			end
		end

		local function apply_markdown_writing_mode(buf, win)
			vim.api.nvim_set_option_value("number", false, { win = win })
			vim.api.nvim_set_option_value("relativenumber", false, { win = win })
			vim.api.nvim_set_option_value("cursorline", false, { win = win })
			vim.api.nvim_set_option_value("colorcolumn", "0", { win = win })
			vim.api.nvim_set_option_value("wrap", true, { win = win })
			vim.api.nvim_set_option_value("linebreak", true, { win = win })
			vim.api.nvim_set_option_value("breakindent", true, { win = win })
			vim.api.nvim_set_option_value("breakindentopt", "sbr", { win = win })
			vim.api.nvim_set_option_value("showbreak", "  ", { win = win })
			vim.api.nvim_set_option_value("spell", true, { win = win })
		end

		local function toggle_markdown_writing_mode()
			local buf = vim.api.nvim_get_current_buf()
			local win = vim.api.nvim_get_current_win()

			if vim.bo[buf].filetype ~= "markdown" then
				vim.notify("Markdown writing mode only works in markdown buffers", vim.log.levels.INFO)
				return
			end

			local state = vim.w.markdown_writing_mode
			if state then
				restore_state(buf, win, state)
				vim.w.markdown_writing_mode = nil
				require("zen-mode").toggle()
				return
			end

			require("zen-mode").toggle()
			vim.w.markdown_writing_mode = save_state(buf, win)
			apply_markdown_writing_mode(buf, win)
		end

		vim.api.nvim_create_user_command("MarkdownWritingMode", toggle_markdown_writing_mode, {
			desc = "Toggle markdown writing mode",
		})
	end,
}

local web_icons = { "nvim-tree/nvim-web-devicons", lazy = true, opts = {} }

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
	ft = "qf",
	config = function()
		require("bqf").setup()
	end,
}

local neoscroll = {
	"karb94/neoscroll.nvim",
	event = "VeryLazy",
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
					silent = true,
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
				-- inc_rename = false, -- enables an input dialog for inc_rename.nvim
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
