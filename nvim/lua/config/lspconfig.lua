local M = {}

M.capabilities = vim.lsp.protocol.make_client_capabilities()

M.init = function(client)
	if client.supports_method("textDocument/semanticTokens") then
		client.server_capabilities.semanticTokensProvider = nil
	end
end

local lsp_list = {
	"pyright",
	"lua_ls",
	"rust_analyzer",
	"markdown_oxide",
	"html",
	"cssls",
	"tailwindcss",
	"quick_lint_js",
}

for _, lsp in ipairs(lsp_list) do
	vim.lsp.config[lsp] = {
		capabilities = require("blink.cmp").get_lsp_capabilities(M.capabilities),
		on_init = M.init,
	}
end

local vue_language_server_path = vim.fn.stdpath("data")
	.. "/mason/packages/vue-language-server/node_modules/@vue/language-server"

-- tsgo: TypeScript-native LSP for TS/JS files
vim.lsp.config.tsgo = {
	capabilities = require("blink.cmp").get_lsp_capabilities(M.capabilities),
	on_init = M.init,
	cmd = { "tsgo", "--lsp", "--stdio" },
	filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact" },
	root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
}

-- ts_ls: only for Vue (with @vue/typescript-plugin)
vim.lsp.config.ts_ls = {
	capabilities = require("blink.cmp").get_lsp_capabilities(M.capabilities),
	on_init = M.init,
	init_options = {
		plugins = {
			{
				name = "@vue/typescript-plugin",
				location = vue_language_server_path,
				languages = { "vue" },
			},
		},
	},
	filetypes = { "vue" },
}

vim.lsp.config.quick_lint_js = {
	capabilities = require("blink.cmp").get_lsp_capabilities(M.capabilities),
	on_init = M.init,
	filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact", "vue" },
}

-- Enable all configured LSP servers
vim.lsp.enable({ "tsgo", "ts_ls", unpack(lsp_list) })
-- vim.diagnostic.config({ virtual_text = true })
