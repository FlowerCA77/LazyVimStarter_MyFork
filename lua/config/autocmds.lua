-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
pcall(vim.api.nvim_del_augroup_by_name, "lazyvim_wrap")

require("config.autocmds.texthl").config()
require("config.autocmds.pdfastext").config()
require("config.autocmds.binary").config()
require("config.autocmds.disassembly.disassembly").config()
require("config.autocmds.luaexec").config()

-- In Rust code, disable the automatic matching of single quotes to prevent confusion with lifetime markers.
vim.api.nvim_create_autocmd("FileType", {
    pattern = "rust",
    callback = function(args)
        vim.keymap.set("i", "'", function()
            local _, col = unpack(vim.api.nvim_win_get_cursor(0))
            local line = vim.api.nvim_get_current_line()

            if line:sub(col + 1, col + 1) == "'" then
                vim.api.nvim_feedkeys(vim.keycode("<Right>"), "n", false)
            else
                vim.api.nvim_feedkeys("'", "n", false)
            end
        end, {
            buffer = args.buf,
            expr = true,
            desc = "Rust: insert lifecycle ' or skip existing '",
        })
    end,
})

-- Actavite GAP tree-sitter
vim.api.nvim_create_autocmd("FileType", {
    pattern = "gap",
    callback = function() vim.o.commentstring = "#%s" end,
})

-- Jupytext fast preview
vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = "*.ipynb",
    callback = function()
        local out = vim.fn.system({ "jupytext", "--to", "markdown", "--output", "-", vim.fn.expand("%") })
        local buf = vim.api.nvim_get_current_buf()

        vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(out, "\n"))
        vim.bo.buftype = "nofile"
        vim.bo.bufhidden = "wipe"

        vim.api.nvim_exec_autocmds("BufReadPre", { buffer = buf })
        vim.bo.filetype = "markdown"
    end,
})

-- When pure-image buffer leave, destroy it and close it.
vim.api.nvim_create_autocmd("BufLeave", {
    pattern = vim.iter(require("snacks.image").config.formats):map(function(ext) return "*." .. ext end):totable(),
    callback = function(args)
        local function is_buf_displayed(buf)
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == buf then return true end
            end
            return false
        end

        vim.schedule(function()
            local b = args.buf
            if not vim.api.nvim_buf_is_valid(b) then return end
            if vim.api.nvim_get_current_buf() == b then return end
            if is_buf_displayed(b) then return end
            pcall(vim.api.nvim_buf_delete, b, { force = true })
        end)
    end,
})
