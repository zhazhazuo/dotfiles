local M = {}

M.capabilities = vim.lsp.protocol.make_client_capabilities()

M.init = function(client)
	if client.supports_method("textDocument/semanticTokens") then
		client.server_capabilities.semanticTokensProvider = nil
	end
end

local lsp_list = { "pyright", "lua_ls", "markdown_oxide", "html", "cssls", "tailwindcss" }

for _, lsp in ipairs(lsp_list) do
	vim.lsp.config[lsp] = {
		capabilities = require("blink.cmp").get_lsp_capabilities(M.capabilities),
		on_init = M.init,
	}
end

local vue_language_server_path = vim.fn.stdpath("data")
	.. "/mason/packages/vue-language-server/node_modules/@vue/language-server"

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
	filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
}

-- Enable all configured LSP servers
vim.lsp.enable(lsp_list)
vim.lsp.enable("ts_ls")
