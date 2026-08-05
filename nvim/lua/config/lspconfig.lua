local M = {}

M.capabilities = vim.lsp.protocol.make_client_capabilities()
local capabilities = require("blink.cmp").get_lsp_capabilities(M.capabilities)

M.init = function(client)
	if client:supports_method("textDocument/semanticTokens") then
		client.server_capabilities.semanticTokensProvider = nil
	end
end

-- Apply capabilities and on_init to every server (Neovim 0.11+ wildcard).
vim.lsp.config("*", {
	capabilities = capabilities,
	on_init = M.init,
})

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
	"emmet_ls",
	"jinja_lsp",
	"jsonls",
	"yamlls",
}

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

-- Detect a Vue/Nuxt project. tsgo cannot load the Vue plugin, so in a Vue
-- project ts_ls must own both .ts and .vue files. One server, one graph.
local function is_vue_project()
	local root = vim.fs.root(0, { "package.json", ".git" }) or vim.fn.getcwd()
	if vim.fs.find({ "nuxt.config.ts", "nuxt.config.js", "vue.config.js" }, { path = root })[1] then
		return true
	end
	local ok, lines = pcall(vim.fn.readfile, root .. "/package.json")
	return ok and table.concat(lines, "\n"):match('"[%w@/-]*vue[%w-]*"%s*:') ~= nil
end

local vue_project = is_vue_project()

-- tsgo: TypeScript-native LSP for TS/JS files (non-Vue projects only)
vim.lsp.config.tsgo = {
	cmd = { "tsgo", "--lsp", "--stdio" },
	filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact" },
	root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
}

-- ts_ls: owns Vue files always. In a Vue project it also owns TS/JS files
-- (with @vue/typescript-plugin), so rename and references work across .vue and .ts.
vim.lsp.config.ts_ls = {
	init_options = {
		plugins = {
			{
				name = "@vue/typescript-plugin",
				location = vue_language_server_path,
				languages = { "vue" },
			},
		},
	},
	filetypes = vue_project
		and { "vue", "typescript", "javascript", "typescriptreact", "javascriptreact" }
		or { "vue" },
}

vim.lsp.config.html = {
	filetypes = with_extra_filetypes("html", { "hubl", "jinja" }),
}

vim.lsp.config.cssls = {
	filetypes = with_extra_filetypes("cssls", { "csshubl" }),
}

vim.lsp.config.tailwindcss = {
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
	filetypes = with_extra_filetypes("emmet_ls", { "hubl", "jinja", "csshubl" }),
}

vim.lsp.config.jinja_lsp = {
	filetypes = with_extra_filetypes("jinja_lsp", { "hubl" }),
	root_markers = { "jinja-lsp.toml", "pyproject.toml", "Cargo.toml", ".git" },
}

-- JSON/YAML schemas via SchemaStore.nvim
vim.lsp.config.jsonls = {
	settings = {
		json = {
			schemas = require("schemastore").json.schemas(),
			validate = { enable = true },
		},
	},
}

vim.lsp.config.yamlls = {
	settings = {
		yaml = {
			schemaStore = {
				enable = false,
				url = "",
			},
			schemas = require("schemastore").yaml.schemas(),
		},
	},
}

-- Enable all configured LSP servers.
-- Vue project: ts_ls (with Vue plugin) + vue_ls for template support, no tsgo.
-- Other projects: tsgo for TS/JS, ts_ls dormant for Vue only.
if vue_project then
	vim.lsp.enable(vim.list_extend({ "ts_ls", "vue_ls" }, lsp_list))
else
	vim.lsp.enable({ "tsgo", "ts_ls", unpack(lsp_list) })
end
-- vim.diagnostic.config({ virtual_text = true })
