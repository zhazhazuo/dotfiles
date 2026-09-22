local nice_mermaid = {
	"iurysza/nice-mermaid.nvim",
	ft = { "markdown" },
	cmd = { "Mermaid" },
	build = function(plugin)
		local result = vim.system({ "npm", "ci", "--omit=dev" }, {
			cwd = plugin.dir .. "/bridge",
			text = true,
		}):wait()
		if result.code ~= 0 then
			error(result.stderr)
		end
	end,
	opts = {},
	keys = {
		{ "<leader>mm", "<cmd>Mermaid toggle<cr>", desc = "Toggle Mermaid source" },
	},
	config = function(_, opts)
		require("nice_mermaid").setup(opts)

		-- Keep the rendered diagram visible in normal mode and reveal the editable
		-- source as soon as an insert is requested. The preview is a separate
		-- non-modifiable buffer, and `i` there fails with E21 before InsertEnter can
		-- fire, so the window has to leave the preview while the key is still being
		-- dispatched.
		local insert_entry = {
			["i"] = true,
			["I"] = true,
			["a"] = true,
			["A"] = true,
			["o"] = true,
			["O"] = true,
			["c"] = true,
			["C"] = true,
			["s"] = true,
			["S"] = true,
			["R"] = true,
			[vim.api.nvim_replace_termcodes("<Insert>", true, false, true)] = true,
		}
		local previews = {}
		local group = vim.api.nvim_create_augroup("NiceMermaidMode", { clear = true })
		local namespace = vim.api.nvim_create_namespace("nice_mermaid_mode")

		local function has_preview(source)
			for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
				if previews[buffer] and vim.api.nvim_buf_is_loaded(buffer) then
					local number = vim.api.nvim_buf_get_name(buffer):match("^mermaid://(%d+)/")
					if tonumber(number) == source then
						return true
					end
				end
			end
			return false
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			pattern = "mermaid-preview",
			callback = function(event)
				previews[event.buf] = true
			end,
		})
		vim.api.nvim_create_autocmd("BufWipeout", {
			group = group,
			callback = function(event)
				previews[event.buf] = nil
			end,
		})
		-- ModeChanged rather than InsertLeave: leaving insert with CTRL-C does not
		-- fire InsertLeave, but it does report the transition to normal mode. Only
		-- insert/replace transitions are matched so that :Mermaid and command-line
		-- commands are not immediately undone.
		vim.api.nvim_create_autocmd("ModeChanged", {
			group = group,
			pattern = { "i:n", "R:n" },
			callback = function()
				local buffer = vim.api.nvim_get_current_buf()
				if vim.bo[buffer].filetype ~= "markdown" or vim.bo[buffer].buftype ~= "" then
					return
				end
				if not has_preview(buffer) then
					return
				end
				require("nice_mermaid").command("toggle")
			end,
		})

		vim.on_key(nil, namespace)
		vim.on_key(function(key)
			if previews[vim.api.nvim_get_current_buf()] and insert_entry[key] then
				require("nice_mermaid").command("source")
			end
		end, namespace)
	end,
}

local render_markdown = {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = { "markdown", "mermaid-preview" },
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
			overrides = {
				filetype = {
					["mermaid-preview"] = {
						anti_conceal = { enabled = false },
						win_options = {
							concealcursor = { default = "nvic", rendered = "nvic" },
						},
					},
				},
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
  nice_mermaid,
	render_markdown,
}
