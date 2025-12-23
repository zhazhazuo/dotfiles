local project_themes = {
	["Brain"] = "catppuccin",
}

local function get_repo_name()
	local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
	if not handle then return nil end
	local result = handle:read("*a")
	handle:close()
	result = result:gsub("%s+$", "")
	if result ~= "" then
		return vim.fn.fnamemodify(result, ":t")
	end
	return nil
end

local current_theme = nil

vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
	callback = function()
		local repo = get_repo_name()
		local theme = repo and project_themes[repo]
		if theme and theme ~= current_theme then
			current_theme = theme
			vim.cmd.colorscheme(theme)
		end
	end,
})
