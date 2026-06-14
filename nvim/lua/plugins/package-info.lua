local package_info = {
	"vuki656/package-info.nvim",
	dependencies = { "MunifTanjim/nui.nvim" },
	event = "BufRead package.json",
	config = function()
		require("package-info").setup()
	end,
	keys = {
		{ "<leader>cP", "<cmd>lua require('package-info').toggle()<cr>", desc = "Toggle package.json versions" },
		{ "<leader>cU", "<cmd>lua require('package-info').update()<cr>", desc = "Update package" },
		{ "<leader>cI", "<cmd>lua require('package-info').install()<cr>", desc = "Install new package" },
	},
}

return { package_info }
