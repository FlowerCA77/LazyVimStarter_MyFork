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
            desc = "Rust: insert ' or skip existing '",
        })
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("user_wrap", { clear = true }),
    pattern = {
        "text",
        "plaintex",
        "typst",
        "latex",
        "tex",
        "gitcommit",
        "markdown",
        "yaml",
        "toml",
        "json",
        "jsonc",
        "ini",
        "conf",
        "lua",
    },
    callback = function()
        vim.opt_local.wrap = true
        vim.opt_local.linebreak = true
        vim.opt_local.breakindent = true
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("user_spell", { clear = true }),
    pattern = {
        "text",
        "plaintex",
        "typst",
        "latex",
        "tex",
        "gitcommit",
        "markdown",
    },
    callback = function()
        vim.opt_local.spell = true
        vim.opt_local.spelllang = { "en", "cjk" }
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "gap",
    callback = function()
        vim.o.commentstring = "#%s"
    end,
})

local function resolve_hl(name, depth)
    depth = depth or 0
    if depth > 8 then
        return {}
    end

    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name })
    if not ok or type(hl) ~= "table" then
        return {}
    end

    if hl.link then
        return resolve_hl(hl.link, depth + 1)
    end

    return hl
end

local function setup_spell_highlights()
    local info = resolve_hl("DiagnosticInfo")
    local warn = resolve_hl("DiagnosticWarn")
    local hint = resolve_hl("DiagnosticHint")
    local comment = resolve_hl("Comment")

    ---@diagnostic disable-next-line: unused-local
    local info_color = info.sp or info.fg or "#7aa2f7"
    ---@diagnostic disable-next-line: unused-local
    local warn_color = warn.sp or warn.fg or "#e0af68"
    ---@diagnostic disable-next-line: unused-local
    local hint_color = hint.sp or hint.fg or "#7dcfff"
    ---@diagnostic disable-next-line: unused-local
    local comment_color = comment.fg or "#8b919a"

    vim.api.nvim_set_hl(0, "SpellBad", {
        underdashed = true,
        sp = info_color,
    })

    vim.api.nvim_set_hl(0, "SpellCap", {
        underdotted = true,
        fg = comment_color,
    })

    vim.api.nvim_set_hl(0, "SpellRare", {
        fg = comment_color,
    })

    vim.api.nvim_set_hl(0, "SpellLocal", {
        fg = hint_color,
    })
end

vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = setup_spell_highlights,
})

setup_spell_highlights()

vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = "*.ipynb",
    callback = function()
        local out = vim.fn.system({
            "jupytext",
            "--to",
            "markdown",
            "--output",
            "-",
            vim.fn.expand("%"),
        })

        vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(out, "\n"))
        vim.bo.filetype = "markdown"
        vim.bo.buftype = "nofile"
        vim.bo.bufhidden = "wipe"
    end,
})
