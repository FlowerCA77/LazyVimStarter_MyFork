local M = { last_code = nil }

local function open_luaexec()
    local original_win = vim.api.nvim_get_current_win()
    local original_buf = vim.api.nvim_get_current_buf()

    local buf = vim.api.nvim_create_buf(false, true)

    local fake_path = vim.fn.stdpath("config") .. "/.scratch_" .. os.time() .. ".lua"
    vim.api.nvim_buf_set_name(buf, fake_path)

    vim.bo[buf].filetype = "lua"
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].swapfile = false
    vim.bo[buf].undofile = false
    vim.bo[buf].modifiable = true

    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            vim.notify("luaexec: Ignore BufWriteCmd", vim.log.levels.INFO)
            vim.bo[buf].modified = false
        end,
    })

    vim.schedule(function()
        local clients = vim.lsp.get_clients({ name = "lua_ls" })
        if #clients > 0 then
            vim.lsp.buf_attach_client(buf, clients[1].id)
        else
            vim.lsp.start({
                name = "lua_ls",
                cmd = { "lua-language-server" },
                root_dir = vim.fn.stdpath("config"),
                settings = {
                    Lua = {
                        workspace = {
                            library = vim.api.nvim_get_runtime_file("", true),
                            checkThirdParty = false,
                        },
                        telemetry = { enable = false },
                    },
                },
            }, { bufnr = buf })
        end
    end)

    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.4)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local base_config = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " luaexec ",
        title_pos = "center",
        footer = " <CR> Execute   <ESC> Cancel ",
        footer_pos = "center",
    }

    local win = vim.api.nvim_open_win(buf, true, base_config)

    vim.wo[win].wrap = false
    vim.wo[win].number = true
    vim.wo[win].relativenumber = false

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        once = true,
        callback = function()
            if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        end,
    })

    vim.api.nvim_create_autocmd("QuitPre", {
        buffer = buf,
        callback = function() vim.bo[buf].modified = false end,
    })

    vim.api.nvim_create_autocmd("ModeChanged", {
        buffer = buf,
        callback = function()
            local m = vim.api.nvim_get_mode().mode
            local footer_text = ""

            if m == "n" then
                footer_text = " <CR> Execute   <q|Esc> Cancel "
            elseif m:match("^[iR]") then
                footer_text = " <C-CR> Execute   <Esc-q|Esc-Esc> Cancel "
            elseif m:match("^[vV\22]") then
                footer_text = " <Esc-q|Esc-Esc> Cancel "
            else
                footer_text = ""
            end

            base_config.footer = footer_text
            base_config.footer_pos = "center"
            vim.api.nvim_win_set_config(win, base_config)
        end,
    })

    local sandbox = setmetatable({}, { __index = _G })

    local function apply_last_code(action)
        if not last_code then return end

        local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local last_lines = vim.split(last_code, "\n")
        local new_lines = {}

        if action == "Replace" then
            new_lines = last_lines
        elseif action == "Prepend" then
            vim.list_extend(new_lines, last_lines)
            vim.list_extend(new_lines, { "" })
            vim.list_extend(new_lines, current_lines)
        elseif action == "Append" then
            vim.list_extend(new_lines, current_lines)
            if #current_lines > 0 and current_lines[#current_lines] ~= "" then vim.list_extend(new_lines, { "" }) end
            vim.list_extend(new_lines, last_lines)
        elseif action == "Copy" then
            pcall(vim.fn.setreg, "+", last_code)
            vim.notify("Copied last command to clipboard", vim.log.levels.INFO)
            return
        end

        local should_format = (action == "Prepend" or action == "Append")
        local format_hint = ""
        local test_code = table.concat(new_lines, "\n")

        if should_format and not loadstring(test_code) then
            should_format = false
            format_hint = " (format skipped: incomplete syntax)"
        end

        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
        vim.bo[buf].modified = true

        if should_format then
            local ok_format = pcall(vim.lsp.buf.format, { bufnr = buf, async = false, timeout_ms = 1000 })
            if ok_format then
                vim.notify("Applied last command (" .. action .. ") and formatted", vim.log.levels.INFO)
            else
                vim.notify("Applied last command (" .. action .. "), format failed", vim.log.levels.WARN)
            end
        else
            vim.notify("Applied last command (" .. action .. ")" .. format_hint, vim.log.levels.INFO)
        end

        vim.cmd("startinsert")
    end

    vim.keymap.set({ "n", "i" }, "<Up>", function()
        if vim.api.nvim_win_get_cursor(win)[1] == 1 and last_code and last_code ~= "" then
            vim.ui.select(
                { "Replace", "Prepend", "Append", "Copy" },
                { prompt = "Apply last successful command as:" },
                function(choice)
                    vim.api.nvim_set_current_win(win)
                    if choice then
                        apply_last_code(choice)
                    else
                        vim.cmd("startinsert")
                    end
                end
            )
        else
            local keys = vim.api.nvim_replace_termcodes("<Up>", true, false, true)
            vim.api.nvim_feedkeys(keys, "n", false)
        end
    end, { buffer = buf })

    local function execute()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local code = table.concat(lines, "\n")
        if code:match("^%s*$") then
            vim.api.nvim_win_close(win, true)
            return
        end

        local chunk, load_err = loadstring(code)
        if not chunk then
            vim.notify("Syntax Error: " .. load_err, vim.log.levels.ERROR)
            return
        end

        if setfenv then setfenv(chunk, sandbox) end

        vim.api.nvim_set_current_win(original_win)
        vim.api.nvim_set_current_buf(original_buf)

        local ok, runtime_err = pcall(chunk)
        if ok then
            if code:match("%S") then last_code = code end
            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
            vim.bo[buf].modified = false
            vim.api.nvim_set_current_win(win)
        else
            vim.notify("Runtime Error: " .. tostring(runtime_err), vim.log.levels.ERROR)
            vim.api.nvim_set_current_win(win)
        end

        vim.cmd("stopinsert")
    end

    vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = buf })
    vim.keymap.set("n", "<CR>", execute, { buffer = buf, nowait = true })
    vim.keymap.set("i", "<C-CR>", execute, { buffer = buf, nowait = true })

    vim.keymap.set({ "n" }, "<Esc>", function()
        vim.api.nvim_win_close(win, true)
        vim.cmd("stopinsert")
    end, { buffer = buf, nowait = true })

    vim.keymap.set({ "n" }, "q", function()
        vim.api.nvim_win_close(win, true)
        vim.cmd("stopinsert")
    end, { buffer = buf, nowait = true })
end

function M.config()
    vim.keymap.set("n", "<leader>uN", open_luaexec, { desc = "luaexec: Execute Lua code on current buffer" })
end

return M
