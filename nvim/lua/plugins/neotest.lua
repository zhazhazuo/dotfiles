local neotest = {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		-- Adapters for languages actually used
		"nvim-neotest/neotest-python",
		"rouge8/neotest-rust",
		"nvim-neotest/neotest-jest",
		"marilari88/neotest-vitest",
	},
	keys = {
		{ "<leader>tt", function() require("neotest").run.run() end, desc = "Run nearest test" },
		{ "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run current file tests" },
		{ "<leader>ta", function() require("neotest").run.run({ suite = true }) end, desc = "Run all tests" },
		{ "<leader>tl", function() require("neotest").run.run_last() end, desc = "Run last test" },
		{ "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle test summary" },
		{
			"<leader>to",
			function() require("neotest").output.open({ enter = true, auto_close = true }) end,
			desc = "Open test output",
		},
		{ "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle output panel" },
		{ "<leader>tw", function() require("neotest").watch.toggle() end, desc = "Toggle test watch" },
	},
	config = function()
		require("neotest").setup({
			adapters = {
				require("neotest-python"),
				require("neotest-rust"),
				require("neotest-jest"),
				require("neotest-vitest"),
			},
			status = { virtual_text = true },
			output = { open_on_run = false },
			quickfix = {
				open = function()
					vim.cmd("copen")
				end,
			},
		})
	end,
}

return { neotest }
