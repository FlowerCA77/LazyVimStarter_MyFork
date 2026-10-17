local M = {}

local function open_luaexec()
    local original_win = vim.api.nvim_get_current_win()
    local original_buf = vim.api.nvim_get_current_buf()

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "lua"

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

    vim.api.nvim_create_autocmd("ModeChanged", {
        buffer = buf,
        callback = function()
            local m = vim.api.nvim_get_mode().mode
            local footer_text = ""

            if m == "n" then
                footer_text = " <CR> Execute   <Esc> Cancel "
            elseif m:match("^[iR]") then
                footer_text = " <C-CR> Execute   <Esc-Esc> Cancel "
            elseif m:match("^[vV\22]") then
                footer_text = " <Esc> to Normal "
            else
                footer_text = ""
            end

            base_config.footer = footer_text
            base_config.footer_pos = "center"
            vim.api.nvim_win_set_config(win, base_config)
        end,
    })

    local sandbox = setmetatable({}, { _index = _G })

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
            if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        else
            vim.notify("Runtime Error: " .. tostring(runtime_err), vim.log.levels.ERROR)
            vim.api.nvim_set_current_win(win)
        end

        vim.cmd("stopinsert")
    end

    vim.keymap.set("n", "<CR>", execute, { buffer = buf, nowait = true })
    vim.keymap.set("i", "<C-CR>", execute, { buffer = buf, nowait = true })
    vim.keymap.set({ "n" }, "<Esc>", function()
        vim.api.nvim_win_close(win, true)
        vim.cmd("stopinsert")
    end, { buffer = buf, nowait = true })
end

function M.config()
    vim.keymap.set("n", "<leader>uN", open_luaexec, { desc = "luaexec: Execute Lua code on current buffer" })
end

return M
