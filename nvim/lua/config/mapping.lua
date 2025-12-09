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
	require("persistence").load()
end

-- Register the command
vim.api.nvim_create_user_command("RW", reset_the_world, { nargs = 0 })

-- For motion
map("i", "<C-h>", "<Left>", { desc = "move left" })
map("i", "<C-l>", "<Right>", { desc = "move right" })
map("i", "<C-j>", "<Down>", { desc = "move down" })
map("i", "<C-k>", "<Up>", { desc = "move up" })
map("i", "<C-E>", "<C-o>$", { noremap = true, desc = "move to end" })

-- For terminal
map("t", "<C-X>", "<C-\\><C-n>", { desc = "Quit from T mode" })

map("n", "gU", [[:<C-u>s/\<./\u&/g<CR> :nohlsearch<CR>]], { desc = "Upper the First Letter" })

map("n", "<leader>cp", ':let @+ = expand("%:p")<CR>', { desc = "Copy The Current File Path." })
