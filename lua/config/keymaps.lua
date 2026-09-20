-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

for _, mode in ipairs({ "n", "i", "v", "x" }) do
    pcall(vim.keymap.del, mode, "<M-j>")
    pcall(vim.keymap.del, mode, "<M-k>")
end

vim.keymap.set(
    "n",
    "<M-Up>",
    "<Cmd>execute 'move .-' . (v:count1 + 1)<CR>==",
    { desc = "Move Up", silent = true }
)

vim.keymap.set(
    "n",
    "<M-Down>",
    "<Cmd>execute 'move .+' . v:count1<CR>==",
    { desc = "Move Down", silent = true }
)

vim.keymap.set(
    "i",
    "<M-Up>",
    "<Esc><Cmd>execute 'move .-' . (v:count1 + 1)<CR>==gi",
    { desc = "Move Up", silent = true }
)

vim.keymap.set(
    "i",
    "<M-Down>",
    "<Esc><Cmd>execute 'move .+' . v:count1<CR>==gi",
    { desc = "Move Down", silent = true }
)

vim.keymap.set(
    "x",
    "<M-Up>",
    ":m '<-2<CR>gv=gv",
    { desc = "Move Selection Up", silent = true }
)

vim.keymap.set(
    "x",
    "<M-Down>",
    ":m '>+1<CR>gv=gv",
    { desc = "Move Selection Down", silent = true }
)

vim.keymap.set(
    "i",
    "<Up>",
    "<C-o>gk",
    { silent = true, desc = "Move up screen line" }
)

vim.keymap.set(
    "i",
    "<Down>",
    "<C-o>gj",
    { silent = true, desc = "Move down screen line" }
)
