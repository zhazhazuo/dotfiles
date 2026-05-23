local M = {}

M.capabilities = vim.lsp.protocol.make_client_capabilities()
local capabilities = require("blink.cmp").get_lsp_capabilities(M.capabilities)

M.init = function(client)
	if client:supports_method("textDocument/semanticTokens") then
		client.server_capabilities.semanticTokensProvider = nil
	end
end

vim.filetype.add({
	extension = {
		hubl = "hubl",
		j2 = "jinja",
		jinja = "jinja",
		jinja2 = "jinja",
	},
})

pcall(vim.treesitter.language.register, "html", "hubl")
pcall(vim.treesitter.language.register, "html", "jinja")
pcall(vim.treesitter.language.register, "css", "csshubl")

local hubspot_root_markers = {
	"hubspot.config.yml",
	"hubspot.config.yaml",
	"hsproject.json",
	"cms-assets.json",
	"theme.json",
	"fields.json",
}

local function set_hubspot_filetype(bufnr, filename)
	if filename == "" or not vim.fs.root(bufnr, hubspot_root_markers) then
		return
	end

	local ext = vim.fn.fnamemodify(filename, ":e")
	if ext == "html" then
		vim.bo[bufnr].filetype = "hubl"
	elseif ext == "css" then
		vim.bo[bufnr].filetype = "csshubl"
	end
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
	group = vim.api.nvim_create_augroup("HubSpotFiletypes", { clear = true }),
	pattern = { "*.html", "*.css" },
	callback = function(event)
		set_hubspot_filetype(event.buf, event.file)
	end,
})

set_hubspot_filetype(0, vim.api.nvim_buf_get_name(0))

local lsp_list = {
	"pyright",
	"lua_ls",
	"rust_analyzer",
	"markdown_oxide",
	"html",
	"cssls",
	"tailwindcss",
	"quick_lint_js",
	"emmet_ls",
	"jinja_lsp",
}

for _, lsp in ipairs(lsp_list) do
	vim.lsp.config[lsp] = {
		capabilities = capabilities,
		on_init = M.init,
	}
end

local function with_extra_filetypes(lsp, extra_filetypes)
	local filetypes = vim.deepcopy(vim.lsp.config[lsp].filetypes or {})
	local seen = {}

	for _, filetype in ipairs(filetypes) do
		seen[filetype] = true
	end

	for _, filetype in ipairs(extra_filetypes) do
		if not seen[filetype] then
			table.insert(filetypes, filetype)
		end
	end

	return filetypes
end

local vue_language_server_path = vim.fn.stdpath("data")
	.. "/mason/packages/vue-language-server/node_modules/@vue/language-server"

-- tsgo: TypeScript-native LSP for TS/JS files
vim.lsp.config.tsgo = {
	capabilities = capabilities,
	on_init = M.init,
	cmd = { "tsgo", "--lsp", "--stdio" },
	filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact" },
	root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
}

-- ts_ls: only for Vue (with @vue/typescript-plugin)
vim.lsp.config.ts_ls = {
	capabilities = capabilities,
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
	capabilities = capabilities,
	on_init = M.init,
	filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact", "vue" },
}

vim.lsp.config.html = {
	capabilities = capabilities,
	on_init = M.init,
	filetypes = with_extra_filetypes("html", { "hubl", "jinja" }),
}

vim.lsp.config.cssls = {
	capabilities = capabilities,
	on_init = M.init,
	filetypes = with_extra_filetypes("cssls", { "csshubl" }),
}

vim.lsp.config.tailwindcss = {
	capabilities = capabilities,
	on_init = M.init,
	filetypes = with_extra_filetypes("tailwindcss", { "hubl", "jinja", "csshubl" }),
	settings = {
		tailwindCSS = {
			includeLanguages = {
				csshubl = "css",
				hubl = "html",
				jinja = "html",
			},
		},
	},
}

vim.lsp.config.emmet_ls = {
	capabilities = capabilities,
	on_init = M.init,
	filetypes = with_extra_filetypes("emmet_ls", { "hubl", "jinja", "csshubl" }),
}

vim.lsp.config.jinja_lsp = {
	capabilities = capabilities,
	on_init = M.init,
	filetypes = with_extra_filetypes("jinja_lsp", { "hubl" }),
	root_markers = { "jinja-lsp.toml", "pyproject.toml", "Cargo.toml", ".git" },
}

-- Enable all configured LSP servers
vim.lsp.enable({ "tsgo", "ts_ls", unpack(lsp_list) })
-- vim.diagnostic.config({ virtual_text = true })
