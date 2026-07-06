local render_markdown = {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = "markdown",
	dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
	---@module 'render-markdown'
	---@type render.md.UserConfig
	config = function()
		local palette = require("focus-walker.palette")
		local set_hl = vim.api.nvim_set_hl

		set_hl(0, "RenderMarkdownTodo", { fg = palette.yellow })
		set_hl(0, "RenderMarkdownWarn", { fg = palette.red })
		set_hl(0, "RenderMarkdownDoing", { fg = palette.green })
		set_hl(0, "RenderMarkdownDone", { fg = palette.blue })
		set_hl(0, "RenderMarkdownCancel", { fg = palette.comment_muted })
		set_hl(0, "RenderMarkdownInfo", { fg = palette.cyan })
		set_hl(0, "RenderMarkdownSuccess", { fg = palette.green })
		set_hl(0, "RenderMarkdownHint", { fg = palette.purple })
		set_hl(0, "RenderMarkdownLink", { fg = palette.blue, underline = true })
		set_hl(0, "RenderMarkdownWikiLink", { fg = palette.cyan, underline = true })
		set_hl(0, "RenderMarkdownCode", { bg = palette.bg_darker })
		set_hl(0, "RenderMarkdownCodeInline", { bg = palette.selection, fg = palette.fg })
		set_hl(0, "RenderMarkdownCodeBorder", { fg = palette.selection, bg = palette.bg_darker })
		set_hl(0, "RenderMarkdownCodeInfo", { fg = palette.comment_muted, bg = palette.bg_darker })
		set_hl(0, "RenderMarkdownBullet", { fg = palette.comment_muted })
		set_hl(0, "RenderMarkdownDash", { fg = palette.selection })
		set_hl(0, "RenderMarkdownTableHead", { fg = palette.blue, bg = palette.bg_darker })
		set_hl(0, "RenderMarkdownTableRow", { fg = palette.fg, bg = palette.bg_darker })
		set_hl(0, "RenderMarkdownQuote1", { fg = palette.blue })
		set_hl(0, "RenderMarkdownQuote2", { fg = palette.cyan })
		set_hl(0, "RenderMarkdownQuote3", { fg = palette.green })
		set_hl(0, "RenderMarkdownQuote4", { fg = palette.yellow })
		set_hl(0, "RenderMarkdownQuote5", { fg = palette.purple })
		set_hl(0, "RenderMarkdownQuote6", { fg = palette.red })
		set_hl(0, "RenderMarkdownH1", { fg = palette.blue, bold = true })
		set_hl(0, "RenderMarkdownH2", { fg = palette.cyan, bold = true })
		set_hl(0, "RenderMarkdownH3", { fg = palette.green, bold = true })
		set_hl(0, "RenderMarkdownH4", { fg = palette.yellow, bold = true })
		set_hl(0, "RenderMarkdownH5", { fg = palette.purple, bold = true })
		set_hl(0, "RenderMarkdownH6", { fg = palette.red, bold = true })
		set_hl(0, "RenderMarkdownH1Bg", { bg = palette.bg_darker })
		set_hl(0, "RenderMarkdownH2Bg", { bg = palette.bg_darker })
		set_hl(0, "RenderMarkdownH3Bg", { bg = palette.bg_darker })
		set_hl(0, "RenderMarkdownH4Bg", { bg = palette.bg_darker })
		set_hl(0, "RenderMarkdownH5Bg", { bg = palette.bg_darker })
		set_hl(0, "RenderMarkdownH6Bg", { bg = palette.bg_darker })

		require("render-markdown").setup({
			enabled = false,
			completions = {
				lsp = { enabled = true },
			},
			anti_conceal = {
				enabled = true,
				-- above = 1,
				-- below = 1,
				ignore = {
					code_background = true,
					indent = true,
					sign = true,
					virtual_lines = true,
				},
			},
			heading = {
				sign = false,
				position = "inline",
				width = "block",
				left_pad = 1,
				right_pad = 1,
				icons = { "󰼏 ", "󰎨 ", "󰼐 ", "󰎲 ", "󰼑 ", "󰎴 " },
			},
			bullet = {
				icons = { "●", "○", "◆", "◇" },
				left_pad = 1,
				right_pad = 1,
				highlight = "RenderMarkdownBullet",
			},
			checkbox = {
				enabled = true,
				bullet = false,
				right_pad = 1,
				-- unchecked
				unchecked = {
					icon = "󰄱 ",
					highlight = "RenderMarkdownTodo",
				},

				-- checked
				checked = {
					icon = "󰄲 ",
					highlight = "RenderMarkdownDone",
				},
				-- custom states
				custom = {
					doing = {
						raw = "[>]",
						rendered = " ",
						highlight = "RenderMarkdownDoing",
					},
					deferred = {
						raw = "[-]",
						rendered = "󰍶 ",
						highlight = "RenderMarkdownCancel",
					},
					important = {
						raw = "[!]",
						rendered = " ",
						highlight = "RenderMarkdownWarn",
					},
					canceled = {
						raw = "[~]",
						rendered = "󰰱 ",
						highlight = "RenderMarkdownCancel",
					},
				},
			},
			code = {
				sign = false,
				width = "block",
				min_width = 60,
				left_pad = 1,
				right_pad = 1,
				language_pad = 1,
				border = "thin",
				inline_pad = 1,
				highlight = "RenderMarkdownCode",
				highlight_info = "RenderMarkdownCodeInfo",
				highlight_border = "RenderMarkdownCodeBorder",
				highlight_inline = "RenderMarkdownCodeInline",
			},
			dash = {
				icon = "─",
				width = "full",
				highlight = "RenderMarkdownDash",
			},
			quote = {
				icon = "▍",
				repeat_linebreak = true,
			},
			pipe_table = {
				preset = "round",
				cell = "padded",
				padding = 1,
				border_enabled = true,
				head = "RenderMarkdownTableHead",
				row = "RenderMarkdownTableRow",
			},
			link = {
				enabled = true,
				wiki = {
					enabled = true,
					icon = "󱗖 ",
					conceal_destination = true,
					highlight = "RenderMarkdownWikiLink",
				},
				custom = {
					repo = { icon = "󰊤 ", pattern = "github%.com", kind = "url", highlight = "RenderMarkdownLink" },
					note = { icon = "󱞁 ", pattern = "%.md$", kind = "suffix", highlight = "RenderMarkdownWikiLink" },
				},
			},
			win_options = {
				concealcursor = {
					default = vim.o.concealcursor,
					rendered = "",
				},
				conceallevel = {
					default = vim.o.conceallevel,
					rendered = 3,
				},
				breakindent = {
					default = vim.wo.breakindent,
					rendered = true,
				},
				breakindentopt = {
					default = vim.wo.breakindentopt,
					rendered = "",
				},
				showbreak = {
					default = vim.wo.showbreak,
					rendered = "  ",
				},
			},
		})

		vim.api.nvim_create_user_command("MarkdownToggle", function()
			require("render-markdown").toggle()
		end, { desc = "Toggle markdown preview/raw mode" })
	end,
}

return {
	render_markdown,
}
