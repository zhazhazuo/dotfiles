local lazygit = {
	{
		"kdheepak/lazygit.nvim",
		cmd = "LazyGit",
		config = function()
			require("telescope").load_extension("lazygit")
		end,
	},
}

local diff_view = {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewToggleFiles" },
	dependencies = {
		"TimUntersberger/neogit",
	},
	config = function()
		require("diffview").setup()
	end,
}

local gitsigns = {
	"lewis6991/gitsigns.nvim",
	event = "VimEnter",
	dependencies = {
		{
			"sindrets/diffview.nvim",
			config = true,
		},
	},
	opts = {
		signs = {
			add = { text = "▎" },
			change = { text = "▎" },
			delete = { text = "" },
			topdelete = { text = "" },
			changedelete = { text = "▎" },
			untracked = { text = "▎" },
		},
		signs_staged = {
			add = { text = "┃" },
			change = { text = "┃" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
			untracked = { text = "┆" },
		},
		auto_attach = true,
		attach_to_untracked = false,
		current_line_blame = true,
		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
			delay = 1000,
			ignore_whitespace = false,
			virt_text_priority = 100,
			use_focus = true,
		},
		current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
		on_attach = function(buffer)
			local gs = package.loaded.gitsigns

			local function map(mode, l, r, desc)
				vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
			end

			map("n", "]h", gs.next_hunk, "Next Hunk")
			map("n", "[h", gs.prev_hunk, "Prev Hunk")
			map({ "n", "v" }, "<leader>hs", ":Gitsigns stage_hunk<CR>", "Stage Hunk")
			map({ "n", "v" }, "<leader>hr", ":Gitsigns reset_hunk<CR>", "Reset Hunk")
			map("n", "<leader>hS", gs.stage_buffer, "Stage Buffer")
			map("n", "<leader>hu", gs.undo_stage_hunk, "Undo Stage Hunk")
			map("n", "<leader>hR", gs.reset_buffer, "Reset Buffer")
			map("n", "<leader>hp", gs.preview_hunk, "Preview Hunk")
			map("n", "<leader>hb", function()
				gs.blame_line({ full = true })
			end, "Blame Line")
			map("n", "<leader>hd", gs.diffthis, "Diff This")
			map("n", "<leader>hD", function()
				gs.diffthis("~")
			end, "Diff This ~")
			map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
		end,
	},
}

local config = {
	diff_view,
	gitsigns,
	lazygit,
}

return config
