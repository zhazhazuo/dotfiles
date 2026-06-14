local overseer = {
	"stevearc/overseer.nvim",
	cmd = {
		"OverseerOpen",
		"OverseerClose",
		"OverseerToggle",
		"OverseerRun",
		"OverseerInfo",
		"OverseerBuild",
		"OverseerQuickAction",
		"OverseerTaskAction",
		"OverseerClearCache",
	},
	keys = {
		{ "<leader>or", "<cmd>OverseerRun<cr>", desc = "Run task" },
		{ "<leader>ot", "<cmd>OverseerToggle<cr>", desc = "Toggle task list" },
		{ "<leader>oc", "<cmd>OverseerClose<cr>", desc = "Close task list" },
		{ "<leader>oi", "<cmd>OverseerInfo<cr>", desc = "Task info" },
		{ "<leader>ob", "<cmd>OverseerBuild<cr>", desc = "Build task" },
	},
	opts = {
		task_list = {
			direction = "bottom",
			min_height = 25,
			max_height = 25,
			default_detail = 1,
		},
		-- Load common task providers (package.json scripts, Makefile, etc.)
		templates = { "builtin" },
	},
	config = function(_, opts)
		require("overseer").setup(opts)
	end,
}

return { overseer }
