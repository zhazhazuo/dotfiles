local lua_snip = {
	"L3MON4D3/LuaSnip",
	-- follow latest release.
	version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
	-- install jsregexp (optional!).
	build = "make install_jsregexp",
	config = function()
		require("luasnip.loaders.from_vscode").lazy_load()
	end,
}

local lazy_dev = {
	"folke/lazydev.nvim",
	ft = "lua", -- only load on lua files
	opts = {
		library = {
			-- See the configuration section for more details
			-- Load luvit types when the `vim.uv` word is found
			{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
		},
	},
	init = function()
		require("lazydev").setup({
			library = { "nvim-dap-ui" },
		})
	end,
}

local blink = {
	"saghen/blink.cmp",
	dependencies = { "rafamadriz/friendly-snippets", "moyiz/blink-emoji.nvim" },

	-- use a release tag to download pre-built binaries
	version = "1.*",
	opts = {
		keymap = { preset = "default" },

		appearance = {
			nerd_font_variant = "normal",
		},

		cmdline = {
			enabled = true,
			completion = {
				menu = {
					auto_show = true,
				},
			},
		},

		completion = {
			keyword = {
				range = "full",
			},
			list = { selection = { preselect = false, auto_insert = true } },
			-- ghost_text = {
			-- 	enabled = true,
			-- 	show_without_selection = true,
			-- },
			menu = {
				border = "rounded",
				-- define highlight to override the background color of menu
				winhighlight = "Normal:Normal,FloatBorder:FloatBorder,Search:None",
				auto_show = false,
				draw = {
					components = {
						kind_icon = {
							text = function(ctx)
								local kind_icon, _, _ = require("mini.icons").get("lsp", ctx.kind)
								return kind_icon
							end,
							-- (optional) use highlights from mini.icons
							highlight = function(ctx)
								local _, hl, _ = require("mini.icons").get("lsp", ctx.kind)
								return hl
							end,
						},
						kind = {
							-- (optional) use highlights from mini.icons
							highlight = function(ctx)
								local _, hl, _ = require("mini.icons").get("lsp", ctx.kind)
								return hl
							end,
						},
					},
				},
			},
			documentation = {
				window = {
					border = "rounded",
				},
				auto_show = false,
			},
		},

		sources = {
			default = { "lsp", "path", "snippets", "buffer", "emoji" },
			providers = {
				cmdline = {
					enabled = function()
						return vim.fn.getcmdtype() ~= ":" or not vim.fn.getcmdline():match("^[%%0-9,'<>%-]*!")
					end,
				},
				emoji = {
					module = "blink-emoji",
					name = "Emoji",
					score_offset = 15, -- the higher the number, the higher the priority
					opts = { insert = true }, -- Insert emoji (default) or complete its name
				},
			},
		},

		fuzzy = { implementation = "prefer_rust_with_warning" },
	},
	opts_extend = { "sources.default" },
}

return {
	lazy_dev,
	lua_snip,
	blink,
}
