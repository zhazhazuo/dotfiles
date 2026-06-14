local map = vim.keymap.set

map("n", "<leader>gg", "<cmd> LazyGit <CR>", {
  desc = "LazyGit",
})

map("n", "<Esc>", "<cmd> nohlsearch <CR>", {
  desc = "Remove Search HL",
})

map("n", "<C-Q>", "<cmd> qa <CR>", {
  desc = "Quit Vim",
})

map("n", "<leader>x", function()
  local win_type = vim.fn.win_gettype()

  if win_type == "quickfix" then
    vim.cmd("cclose")
  elseif win_type == "loclist" then
    vim.cmd("lclose")
  else
    vim.cmd("bdelete")
  end
end, {
  desc = "Close Current Buffer",
  noremap = true,
  nowait = true,
})

map("n", "<leader>k", '<cmd> execute "%bdelete|edit#|bdelete#"<CR>', { desc = "Only keep current buffer" })

local function reset_the_world()
  vim.defer_fn(function()
    require("persistence").load()
  end, 100)
end

local function restart_the_world()
  vim.cmd("restart +RW")
end

-- Register the command
vim.api.nvim_create_user_command("RW", reset_the_world, { nargs = 0 })
vim.api.nvim_create_user_command("REW", restart_the_world, { nargs = 0 })
-- map("n", "<C-R>", restart_the_world, { desc = "Restart The World" })

-- For motion
map("i", "<C-h>", "<Left>", { desc = "move left" })
map("i", "<C-l>", "<Right>", { desc = "move right" })
map("i", "<C-j>", "<Down>", { desc = "move down" })
map("i", "<C-k>", "<Up>", { desc = "move up" })
map("i", "<C-E>", "<C-o>$", { noremap = true, desc = "move to end" })

-- For terminal
map("t", "<C-X>", "<C-\\><C-n>", { desc = "Quit from T mode" })

map("n", "gU", [[:<C-u>s/\<./\u&/g<CR> :nohlsearch<CR>]], { desc = "Upper the First Letter" })

map("n", "<leader>cp", ':let @+ = expand("%:.")<CR>', { desc = "Copy The Current File Path." })

-- For LSP
map("n", "gv", function()
  vim.cmd("botright vsplit")

  vim.lsp.buf.definition()
end, { desc = "LSP: Definition in Vertical Split" })

map("n", "gs", function()
  vim.cmd("split")

  vim.lsp.buf.definition()
end, { desc = "LSP: Definition in H Split" })

map({ "n", "x" }, "<C-Space>", function()
  require("vim.treesitter._select").select_parent(vim.v.count1)
end)

map({ "n", "x" }, "<BS>", function()
  require("vim.treesitter._select").select_child(vim.v.count1)
end)

-- For Refer File
map("n", "<leader>cl", function()
  local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  local text = string.format(
    "%s:%d:%d",
    file,
    vim.fn.line("."),
    vim.fn.col(".")
  )

  vim.fn.setreg("+", text)
  print("Copied location: " .. text)
end, { desc = "Copy Current Cursor Position" })

map("v", "<leader>cr", function()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  local text = string.format(
    "%s:%d-%d",
    file,
    start_line,
    end_line
  )

  vim.fn.setreg("+", text)
  print("Copied range: " .. text)
end, { desc = "Copy file range" })

map("n", "<leader>zm", '<cmd>MarkdownWritingMode<CR>', { desc = "ZenMode for Markdown" })
