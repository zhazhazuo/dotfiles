-- Manual frontmatter commands for markdown notes.
-- Used because obsidian.nvim's automatic frontmatter is disabled in plugins/obsidian.lua.

local M = {}

local function get_lines(buf)
	return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function set_lines(buf, lines)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

-- Returns (has, start_line, end_line) where start_line and end_line are
-- the line numbers (1-indexed) of the opening and closing `---` markers.
local function find_frontmatter(lines)
	if #lines == 0 or lines[1] ~= "---" then
		return false, nil, nil
	end
	for i = 2, #lines do
		if lines[i] == "---" then
			return true, 1, i
		end
	end
	-- opening --- with no closing; treat as malformed
	return false, nil, nil
end

local function build_block(opts)
	opts = opts or {}
	local lines = { "---" }
	if opts.title and opts.title ~= "" then
		lines[#lines + 1] = "title: " .. opts.title
	end
	if opts.tags and #opts.tags > 0 then
		lines[#lines + 1] = "tags:"
		for _, t in ipairs(opts.tags) do
			lines[#lines + 1] = "  - " .. t
		end
	else
		lines[#lines + 1] = "tags: []"
	end
	if opts.aliases and #opts.aliases > 0 then
		lines[#lines + 1] = "aliases:"
		for _, a in ipairs(opts.aliases) do
			lines[#lines + 1] = "  - " .. a
		end
	else
		lines[#lines + 1] = "aliases: []"
	end
	lines[#lines + 1] = "---"
	lines[#lines + 1] = ""
	return lines
end

local function buf_title(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		return nil
	end
	-- strip extension and any %xx escapes
	return vim.fn.fnamemodify(name, ":t"):gsub("%.md$", ""):gsub("%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end)
end

function M.insert(opts)
	local buf = vim.api.nvim_get_current_buf()
	local lines = get_lines(buf)
	if find_frontmatter(lines) then
		vim.notify("Frontmatter already present", vim.log.levels.INFO)
		return
	end
	opts = opts or {}
	if not opts.title or opts.title == "" then
		opts.title = buf_title(buf) or ""
	end
	local block = build_block(opts)
	local merged = {}
	for _, l in ipairs(block) do
		merged[#merged + 1] = l
	end
	for _, l in ipairs(lines) do
		merged[#merged + 1] = l
	end
	set_lines(buf, merged)
end

-- Parse a flat list of fargs like ["title=Hello", "tags=foo,bar"] into opts.
local function parse_fargs(fargs)
	local opts = {}
	for _, arg in ipairs(fargs) do
		local k, v = arg:match("^([%w_]+)=(.+)$")
		if k then
			if k == "tags" or k == "aliases" then
				opts[k] = vim.split(v, ",", { plain = true, trimempty = true })
			else
				opts[k] = v
			end
		end
	end
	return opts
end

function M.setup()
	vim.api.nvim_create_user_command("ObsidianFrontmatter", function(cmd)
		local sub = cmd.args
		if sub == "" or sub == "insert" then
			M.insert(parse_fargs(cmd.fargs))
		else
			vim.notify("Unknown subcommand: " .. sub .. " (use: insert)", vim.log.levels.ERROR)
		end
	end, {
		nargs = "*",
		complete = function(arglead, line, _)
			local subs = { "insert" }
			local matches = {}
			for _, s in ipairs(subs) do
				if vim.startswith(s, arglead) then
					matches[#matches + 1] = s
				end
			end
			if vim.startswith(line, "ObsidianFrontmatter insert") then
				for _, k in ipairs({ "title=", "tags=", "aliases=" }) do
					if vim.startswith(k, arglead) then
						matches[#matches + 1] = k
					end
				end
			end
			return matches
		end,
	})
end

return M
