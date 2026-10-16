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
    callback = function() vim.o.commentstring = "#%s" end,
})

local function resolve_hl(name, depth)
    depth = depth or 0
    if depth > 8 then return {} end

    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name })
    if not ok or type(hl) ~= "table" then return {} end

    if hl.link then return resolve_hl(hl.link, depth + 1) end

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

    vim.api.nvim_set_hl(0, "SpellBad", { underdashed = true, sp = info_color })

    vim.api.nvim_set_hl(0, "SpellCap", { underdotted = true, fg = comment_color })

    vim.api.nvim_set_hl(0, "SpellRare", { fg = comment_color })

    vim.api.nvim_set_hl(0, "SpellLocal", { fg = hint_color })
end

vim.api.nvim_create_autocmd("ColorScheme", { pattern = "*", callback = setup_spell_highlights })

setup_spell_highlights()

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

local pdf_aug = vim.api.nvim_create_augroup("PdfAsText", { clear = true })

vim.api.nvim_create_autocmd("BufReadCmd", {
    group = pdf_aug,

    pattern = "*.pdf",
    callback = function(args)
        local buf = args.buf
        local file = args.file

        if vim.b[buf].snacks_image then vim.b[buf].snacks_image = false end

        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].bufhidden = "hide"
        vim.bo[buf].swapfile = false
        vim.bo[buf].modifiable = true

        local res = vim.system({ "pdftotext", "-layout", "-enc", "UTF-8", file, "-" }, { text = true }):wait()

        local lines
        if res.code == 0 then
            lines = vim.split(res.stdout, "\n", { plain = true })
            if lines[#lines] == "" then lines[#lines] = nil end
        else
            lines = { "pdftotext failed (exit " .. res.code .. "): " .. file, "", res.stderr or "" }
        end

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].filetype = "text"
        vim.bo[buf].modifiable = false
        vim.bo[buf].modified = false
    end,
})

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

local bin_cache = {}
local bin_detect_group = vim.api.nvim_create_augroup("BinaryDetect", { clear = true })

local magic_encoding

do
    local ok, ffi = pcall(require, "ffi")
    if ok then
        ffi.cdef([[
            typedef struct magic_set magic_t;
            magic_t* magic_open(int);
            int magic_load(magic_t*, const char*);
            const char* magic_buffer(magic_t*, const void*, size_t);
        ]])

        local candidates = {
            "/opt/homebrew/lib/libmagic.dylib",
            "/usr/local/lib/libmagic.dylib",
            "libmagic.so.1",
        }

        local lib
        for _, p in ipairs(candidates) do
            local ok2, l = pcall(ffi.load, p)
            if ok2 then
                lib = l
                break
            end
        end

        if lib then
            local cookie = lib.magic_open(0x0000400) -- MAGIC_MIME_ENCODING
            if cookie ~= nil and lib.magic_load(cookie, nil) == 0 then
                magic_encoding = function(head)
                    local p = lib.magic_buffer(cookie, head, #head)
                    if p == nil then return head:find("\0", 1, true) and "binary" or "us-ascii" end
                    return ffi.string(p)
                end
            end
        end
    end

    if not magic_encoding then
        magic_encoding = function(head) return head:find("\0", 1, true) and "binary" or "us-ascii" end
    end
end

local function bin_sniff(path)
    local stat = vim.uv.fs_stat(path)
    if not stat or stat.size == 0 then return false end

    local hit = bin_cache[path]
    if hit ~= nil then return hit end

    local fd = vim.uv.fs_open(path, "r", 438)
    if not fd then return false end
    local head = vim.uv.fs_read(fd, 8192, 0) or ""
    vim.uv.fs_close(fd)

    hit = (magic_encoding(head) == "binary")
    bin_cache[path] = hit
    return hit
end

vim.api.nvim_create_autocmd("BufReadPre", {
    group = bin_detect_group,
    callback = function(args)
        local path = vim.api.nvim_buf_get_name(args.buf)
        if path == "" or vim.fn.filereadable(path) == 0 then return end

        local stat = vim.uv.fs_stat(path)
        if not stat or stat.size == 0 then return end

        if bin_sniff(path) then vim.bo[args.buf].filetype = "binary" end

        vim.b[args.buf].binary_path = path
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    group = bin_detect_group,
    pattern = "binary",

    callback = function(args)
        local buf = args.buf
        if vim.b[buf].hex_inited then return end
        vim.b[buf].hex_inited = true

        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then return end

            vim.bo[buf].modifiable = true

            vim.cmd("silent! %!xxd -g 1 -u -c 16")

            vim.bo[buf].filetype = "xxd"

            vim.bo[buf].modified = false
            vim.b[buf].hex_mode = true
            vim.bo[buf].readonly = true
            vim.bo[buf].modifiable = false
        end)
    end,
})

vim.api.nvim_create_user_command("HexToggle", function()
    local buf = vim.api.nvim_get_current_buf()
    if not vim.b[buf].hex_inited then
        vim.notify("Not a binary buffer", vim.log.levels.WARN)
        return
    end

    vim.bo[buf].modifiable = true

    if vim.b[buf].hex_mode then
        vim.cmd("silent! %!xxd -r")
        vim.bo[buf].filetype = "binary"
        vim.b[buf].hex_mode = false
    else
        vim.cmd("silent! %!xxd -g 1 -u -c 16")
        vim.bo[buf].filetype = "xxd"
        vim.b[buf].hex_mode = true
    end

    vim.bo[buf].modified = false
    vim.bo[buf].readonly = true
    vim.bo[buf].modifiable = false
end, {})

vim.keymap.set("n", "<leader>uHH", "<cmd>HexToggle<cr>", { desc = "Toggle hex view" })

local disasm = require("config.disasm")

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        if vim.b[args.buf].binary_view == "hex" then vim.lsp.buf_detach_client(args.buf, args.data.client_id) end
    end,
})

vim.api.nvim_create_user_command("Disasm", function()
    local buf = vim.api.nvim_get_current_buf()
    local path = vim.b[buf].binary_path
    if not path then
        vim.notify("Not a binary buffer", vim.log.levels.WARN)
        return
    end
    disasm.run(path, function(lines)
        vim.bo[buf].readonly = false
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].filetype = "asm"
        vim.bo[buf].modified = false
        vim.bo[buf].readonly = true
        vim.bo[buf].modifiable = false
        vim.b[buf].binary_view = "disasm"
    end)
end, { desc = "Disassemble with picker" })

vim.keymap.set("n", "<leader>uHD", "<cmd>Disasm<cr>", { desc = "Disasm (pick tool)" })
