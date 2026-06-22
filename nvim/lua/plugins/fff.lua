local config = {
	"dmtrKovalenko/fff.nvim",
	build = function()
		require("fff.download").download_or_build_binary()
	end,
	lazy = false, -- the plugin lazy-initialises itself
	opts = {
		-- Layout mirrors the former snacks.picker "cmdline" layout:
		-- bottom-anchored, full width, 40% height, right preview, bottom prompt.
		layout = {
			anchor = "bottom",
			width = 1.0,
			height = 0.4,
			prompt_position = "bottom",
			preview_position = "right",
			preview_size = 0.6,
			flex = { size = 130, wrap = "top" },
			min_list_height = 10,
			show_scrollbar = true,
			path_shorten_strategy = "middle",
		},
		grep = {
			smart_case = true,
		},
		frecency = {
			enabled = true,
		},
	},
	keys = {
		{
			"<leader>ff",
			function()
				require("fff").find_files()
			end,
			desc = "Find Files",
		},
		{
			"<leader><leader>",
			function()
				require("fff").find_files()
			end,
			desc = "Smart Find Files",
		},
		{
			"<leader>fg",
			function()
				require("fff").find_files()
			end,
			desc = "Find Files (All)",
		},
		{
			"<leader>/",
			function()
				require("fff").live_grep()
			end,
			desc = "Grep",
		},
		{
			"<leader>sw",
			function()
				local query
				if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
					local ok, region = pcall(vim.fn.getregion, 0)
					if ok and region and region[1] then
						query = region[1]
					end
				end
				if not query or query == "" then
					query = vim.fn.expand("<cword>")
				end
				require("fff").live_grep({ query = query })
			end,
			desc = "Visual selection or word",
			mode = { "n", "x" },
		},
	},
}

return config
