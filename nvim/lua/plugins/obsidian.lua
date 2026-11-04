local obsidian = {
	"epwalsh/obsidian.nvim",
	version = "*", -- recommended, use latest release instead of latest commit
	lazy = true,
	ft = "markdown",
	dependencies = {
		-- Required.
		"nvim-lua/plenary.nvim",
	},
	opts = {
		ui = {
			enable = false,
		},
		workspaces = {
			{
				name = "personal",
				path = "~/Research/Brain",
			},
		},
		attachments = {
			img_folder = "5-Achive/Assets",
		},
		completion = {
			nvim_cmp = false,
		},
		disable_frontmatter = true,
	},
}

return {
	obsidian,
}
