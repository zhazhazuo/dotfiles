local codeAction = {
	"aznhe21/actions-preview.nvim",
	enabled = false,
	keys = {
		{
			"gra",
			function()
				require("actions-preview").code_actions()
			end,
			desc = "Toggle Spectre",
		},
	},
}

local tinyCodeAction = {
	"rachartier/tiny-code-action.nvim",
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
	},
	event = "LspAttach",
	opts = {
		picker = {
			"buffer",
		},
	},
	config = function()
		vim.keymap.set("n", "gra", function()
			require("tiny-code-action").code_action()
		end, { noremap = true, silent = true })
	end,
}

local indentScope = {
	"echasnovski/mini.indentscope",
	event = "BufEnter",
	opts = {
		symbol = "│",
		options = { try_as_border = true },
	},
	init = function()
		vim.api.nvim_create_autocmd("FileType", {
			pattern = {
				"help",
				"neo-tree",
				"Trouble",
				"trouble",
				"lazy",
				"dashboard",
				"mason",
				"notify",
				"toggleterm",
			},
			callback = function()
				vim.b.miniindentscope_disable = true
			end,
		})
	end,
}

local hlarg = {
	"m-demare/hlargs.nvim",
	config = function()
		require("hlargs").setup()
	end,
}

local comment = {
	"folke/todo-comments.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
	},
}

-- show the above context when it is outside
local context = {
	"nvim-treesitter/nvim-treesitter-context",
	event = "BufReadPost",
	opts = {
		throttle = true,
		max_lines = 0,
		patterns = {
			default = {
				"class",
				"function",
				"method",
			},
		},
	},
}

local spectre = {
	"nvim-pack/nvim-spectre",
	build = false,
	cmd = "Spectre",
	opts = { open_cmd = "noswapfile vnew" },
	keys = {
		{
			"<leader>sP",
			function()
				require("spectre").Toggle()
			end,
			desc = "Toggle Spectre",
		},
		{
			"<leader>sp",
			function()
				require("spectre").open_file_search({ select_word = true })
			end,
			desc = "Search Word in Current File (Spectre)",
		},
	},
}

local trouble = {
	"folke/trouble.nvim",
	opts = {
		modes = {
			test = {
				mode = "diagnostics",
				preview = {
					type = "split",
					relative = "win",
					position = "right",
					size = 0.3,
				},
			},
		},
	}, -- for default options, refer to the configuration section for custom setup.
	cmd = "Trouble",
	keys = {
		{
			"<leader>tD",
			"<cmd>Trouble diagnostics toggle<cr>",
			desc = "Diagnostics (Trouble)",
		},
		{
			"<leader>td",
			"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
			desc = "Buffer Diagnostics (Trouble)",
		},
		{
			"<leader>cs",
			"<cmd>Trouble symbols toggle focus=false<cr>",
			desc = "Symbols (Trouble)",
		},
		{
			"<leader>cl",
			"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
			desc = "LSP Definitions / references / ... (Trouble)",
		},
		{
			"<leader>xL",
			"<cmd>Trouble loclist toggle<cr>",
			desc = "Location List (Trouble)",
		},
		{
			"<leader>xQ",
			"<cmd>Trouble qflist toggle<cr>",
			desc = "Quickfix List (Trouble)",
		},
	},
}

local lspconfig = {
	"neovim/nvim-lspconfig",
	dependencies = {
		"mason.nvim",
		{ "williamboman/mason-lspconfig.nvim", config = function() end },
	},
}

local mason_packages = {
	-- LSP servers
	"lua-language-server",
	"pyright",
	"typescript-language-server",
	"html-lsp",
	"css-lsp",
	"tailwindcss-language-server",
	"vue-language-server",
	"emmet-ls",
	"json-lsp",
	"yaml-language-server",
	"bash-language-server",
	"graphql-language-service-cli",

	"marksman", -- markdown
	"markdown-oxide", -- obsidian navigation

	-- Linters
	"eslint_d",
	"prettier",

	-- Formatters
	"stylua",
	"black",
	"isort",
	"shfmt",
}

local mason = {
	"williamboman/mason.nvim",
	cmd = "Mason",
	build = ":MasonUpdate",
	opts = {
		ensure_installed = mason_packages,
	},
	config = function(_, opts)
		require("mason").setup(opts)

		-- Create a command to install all packages manually
		vim.api.nvim_create_user_command("MasonInstallAll", function()
			local mr = require("mason-registry")
			local installed = 0
			local total = #opts.ensure_installed

			mr.refresh(function()
				for _, tool in ipairs(opts.ensure_installed or {}) do
					local p = mr.get_package(tool)
					if not p:is_installed() then
						vim.notify("Installing " .. tool, vim.log.levels.INFO)
						p:install():once("closed", function()
							installed = installed + 1
							if installed == total then
								vim.notify("All Mason packages installed!", vim.log.levels.INFO)
							end
						end)
					else
						installed = installed + 1
					end
				end
			end)
		end, { desc = "Install all Mason packages from ensure_installed list" })
	end,
}

local quicker = {
	"stevearc/quicker.nvim",
	ft = "qf",
	---@module "quicker"
	---@type quicker.SetupOptions
	opts = {},
	config = function()
		require("quicker").setup()
	end,
}

return {
	indentScope,
	context,
	spectre,
	trouble,
	comment,
	lspconfig,
	mason,
	-- codeAction,
	quicker,
	tinyCodeAction,
}
