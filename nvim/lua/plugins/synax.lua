local surround = { "echasnovski/mini.surround", version = "*", event = "VeryLazy" }

local treesitter = {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	event = { "BufReadPost", "BufNewFile" },
	build = ":TSUpdate",
	config = function()
		-- Enable highlighting + indentation per Neovim 0.12 / nvim-treesitter main
		local function start_treesitter(buf)
			if pcall(vim.treesitter.start, buf) then
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end
		end

		vim.api.nvim_create_autocmd("FileType", {
			callback = function(ev)
				start_treesitter(ev.buf)
			end,
		})

		local current = vim.api.nvim_get_current_buf()
		if vim.bo[current].filetype ~= "" then
			start_treesitter(current)
		end
	end,
}

local config = {
	treesitter,
	surround,
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		lazy = true,
		opts = {
			textobjects = {
				select = {
					enable = true,
					lookahead = true,
					keymaps = {
						["af"] = "@function.outer",
						["if"] = "@function.inner",
						["ac"] = "@class.outer",
						["ic"] = "@class.inner",
					},
				},
				move = {
					enable = true,
					set_jumps = true,
					goto_next_start = {
						["]f"] = "@function.outer",
						["]c"] = "@class.outer",
					},
					goto_previous_start = {
						["[f"] = "@function.outer",
						["[c"] = "@class.outer",
					},
				},
			},
		},
	},
	{
		"windwp/nvim-ts-autotag",
		event = "VeryLazy",
		opts = {},
	},

	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			require("nvim-autopairs").setup()
		end,
	},
}

return config
