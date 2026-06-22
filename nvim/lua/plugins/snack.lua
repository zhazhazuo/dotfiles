local config = {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		bigfile = { enabled = false },
		notifier = { enabled = true },
		quickfile = { enabled = true },
		rename = { enabled = true },
		words = { enabled = true },
		scope = { enabled = true },
		statuscolumn = { enabled = true },
		input = { enabled = true },
		image = {
			enabled = true,
			img_dirs = {
				-- for obsidian asset
				"5-Achive/Assets",
			},
			doc = {
				-- disabled rendering in place
				inline = false,
			},
		},
		picker = {
			actions = {
				edit_vsplit_right = function(picker, item)
					picker:close()
					if item then
						vim.cmd("botright vsplit " .. item.file)
					end
				end,
			},
			hidden = true,
			ignored = true,
			layout = "cmdline",
			sources = {
				files = {
					cmd = "rg",
					args = {
						"--files",
						"--hidden",
						"--glob", "!.git/",
						"--glob", "!node_modules/",
						"--glob", "!vendor/",
						"--glob", "!dist/",
						"--glob", "!build/",
						"--glob", "!.next/",
						"--glob", "!coverage/",
					},
				},
				grep = {
					cmd = "rg",
					args = {
						"--hidden",
						"--glob", "!.git/",
						"--glob", "!node_modules/",
						"--glob", "!vendor/",
						"--glob", "!dist/",
						"--glob", "!build/",
						"--glob", "!.next/",
						"--glob", "!coverage/",
					},
				},
			},
			layouts = {
				cmdline = {
					layout = {
						box = "vertical",
						backdrop = false,
						row = -1,
						width = 0,
						height = 0.4,
						border = "none",
						title = " {title} {live} {flags}",
						title_pos = "left",
						{
							box = "horizontal",
							{ win = "list", border = "rounded" },
							{ win = "preview", title = "{preview}", width = 0.6, border = "rounded" },
						},
						{ win = "input", height = 1, border = "none" },
					},
				},
			},
			win = {
				input = {
					keys = {
						["<c-v>"] = { "edit_vsplit_right", mode = { "i", "n" } },
					},
				},
				list = {
					keys = {
						["<c-v>"] = "edit_vsplit_right",
					},
				},
			},
		},
	},
	config = function(_, opts)
		require("snacks").setup(opts)

		local function set_picker_highlights()
			vim.api.nvim_set_hl(0, "SnacksPickerListCursorLine", { bg = "#2c2c2c" })

			-- Fix low-contrast picker highlights: Dir/PathHidden/PathIgnored/Unselected
			-- were all linked to NonText (#3f3951) which is invisible on bg (#282433)
			vim.api.nvim_set_hl(0, "SnacksPickerDir", { fg = "#938AAD" })
			vim.api.nvim_set_hl(0, "SnacksPickerPathHidden", { fg = "#6e6587" })
			vim.api.nvim_set_hl(0, "SnacksPickerPathIgnored", { fg = "#6e6587" })
			vim.api.nvim_set_hl(0, "SnacksPickerUnselected", { fg = "#938AAD" })
		end

		set_picker_highlights()
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("snacks-picker-highlights", { clear = true }),
			callback = set_picker_highlights,
		})
	end,
	keys = {
		-- explorer
		{
			"<leader>fl",
			function()
				Snacks.explorer()
			end,
			desc = "File Explorer",
		},
		-- picker
		{
			"<leader>n",
			function()
				Snacks.picker.notifications()
			end,
			desc = "Notification History",
		},
		{
			"<leader>fb",
			function()
				Snacks.picker.buffers()
			end,
			desc = "Buffers",
		},
		{
			"<leader>fr",
			function()
				Snacks.picker.recent()
			end,
			desc = "Recent",
		},
		{
			"<leader>gh",
			function()
				Snacks.picker.git_diff()
			end,
			desc = "Git Diff (Hunks)",
		},
		{
			"<leader>gl",
			function()
				Snacks.picker.git_log()
			end,
			desc = "Git Log",
		},
		{
			"<leader>sk",
			function()
				Snacks.picker.keymaps()
			end,
			desc = "Keymaps",
		},
		-- LSP
		{
			"gd",
			function()
				Snacks.picker.lsp_definitions()
			end,
			desc = "Goto Definition",
		},
		{
			"gD",
			function()
				Snacks.picker.lsp_declarations()
			end,
			desc = "Goto Declaration",
		},
		{
			"gt",
			function()
				Snacks.picker.lsp_references()
			end,
			nowait = true,
			desc = "References",
		},
		{
			"gI",
			function()
				Snacks.picker.lsp_implementations()
			end,
			desc = "Goto Implementation",
		},
		{
			"gy",
			function()
				Snacks.picker.lsp_type_definitions()
			end,
			desc = "Goto T[y]pe Definition",
		},
		{
			"<leader>fs",
			function()
				Snacks.picker.lsp_symbols()
			end,
			desc = "LSP Symbols",
		},
		{
			'<leader>s"',
			function()
				Snacks.picker.registers()
			end,
			desc = "Registers",
		},
		{
			"<leader>st",
			function()
				Snacks.picker.todo_comments()
			end,
			desc = "Todo",
		},
		{
			"<leader>sT",
			function()
				Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } })
			end,
			desc = "Todo/Fix/Fixme",
		},
		{
			"<leader>sb",
			function()
				Snacks.picker.lines()
			end,
			desc = "Buffer Lines",
		},
		{
			"<leader>sB",
			function()
				Snacks.picker.grep_buffers()
			end,
			desc = "Grep Open Buffers",
		},
		{
			"<leader>sd",
			function()
				Snacks.picker.diagnostics()
			end,
			desc = "Diagnostics",
		},
		{
			"<leader>sD",
			function()
				Snacks.picker.diagnostics_buffer()
			end,
			desc = "Buffer Diagnostics",
		},
		{
			"<leader>ss",
			function()
				Snacks.picker.lsp_symbols()
			end,
			desc = "LSP Symbols",
		},
		{
			"<leader>sS",
			function()
				Snacks.picker.lsp_workspace_symbols()
			end,
			desc = "LSP Workspace Symbols",
		},
	},
	init = function()
		local prev = { new_name = "", old_name = "" } -- Prevents duplicate events
		vim.api.nvim_create_autocmd("User", {
			pattern = "NvimTreeSetup",
			callback = function()
				local events = require("nvim-tree.api").events
				events.subscribe(events.Event.NodeRenamed, function(data)
					if prev.new_name ~= data.new_name or prev.old_name ~= data.old_name then
						data = data
						Snacks.rename.on_rename_file(data.old_name, data.new_name)
					end
				end)
			end,
		})
	end,
}

return config
