local tmux_navigator = {
	"christoomey/vim-tmux-navigator",
	cmd = {
		"TmuxNavigateLeft",
		"TmuxNavigateDown",
		"TmuxNavigateUp",
		"TmuxNavigateRight",
		"TmuxNavigatePrevious",
	},
	keys = {
		{ "<C-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
		{ "<C-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
		{ "<C-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
		{ "<C-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
		{ "<C-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
	},
}

local flash = {
	"folke/flash.nvim",
	config = function()
		require("flash").toggle(false)
	end,
	opts = {},
	keys = {
		{
			"<leader>w",
			mode = { "n", "x", "o" },
			function()
				-- Replaces HopWordCurrentLine: label every word on the cursor line.
				require("flash").jump({
					search = { multi_window = false },
					label = { after = { 0, 0 } },
					matcher = function(win)
						local buf = vim.api.nvim_win_get_buf(win)
						local lnum = vim.api.nvim_win_get_cursor(win)[1]
						local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ""
						local matches = {}
						local init = 1
						while true do
							local s, e = line:find("%w+", init)
							if not s then
								break
							end
							matches[#matches + 1] = { pos = { lnum, s - 1 }, end_pos = { lnum, e - 1 } }
							init = e + 1
						end
						return matches
					end,
				})
			end,
			desc = "Flash Word (Current Line)",
		},
		{
			"R",
			mode = { "n", "x", "o" },
			function()
				require("flash").treesitter()
			end,
			desc = "Flash Treesitter",
		},
	},
	specs = {
		{
			"folke/snacks.nvim",
			opts = {
				picker = {
					win = {
						input = {
							keys = {
								["<c-r>"] = { "flash", mode = { "n", "i" } },
								["s"] = { "flash" },
							},
						},
					},
					actions = {
						flash = function(picker)
							require("flash").jump({
								pattern = "^",
								label = { after = { 0, 0 } },
								search = {
									mode = "search",
									exclude = {
										function(win)
											return vim.bo[vim.api.nvim_win_get_buf(win)].filetype
												~= "snacks_picker_list"
										end,
									},
								},
								action = function(match)
									local idx = picker.list:row2idx(match.pos[1])
									picker.list:_move(idx, true, true)
								end,
							})
						end,
					},
				},
			},
		},
	},
}

local leap = {
	url = "https://codeberg.org/andyg/leap.nvim",
	keys = {
		{ "s", "<Plug>(leap)", mode = { "n", "x", "o" }, desc = "Leap" },
		{ "S", "<Plug>(leap-from-window)", mode = "n", desc = "Leap From Window" },
	},
}

return {
	tmux_navigator,
	flash,
	leap,
}
