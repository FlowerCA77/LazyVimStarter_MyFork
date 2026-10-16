local M = {}

local PRESETS = {
    ["llvm-objdump"] = {
        { "disasm", "text section, no raw bytes", { "-d", "--no-show-raw-insn" } },
        { "disasm + raw", "include hex bytes", { "-d" } },
        { "demangled", "symbols demangled", { "-d", "--no-show-raw-insn", "--demangle" } },
        { "all sections", "every section", { "-D", "--no-show-raw-insn" } },
    },
    otool = {
        { "__TEXT,__text", "text section with symbols", { "-tV" } },
        { "text only", "no symbol decoding", { "-t" } },
        { "objc", "Objective-C sections", { "-ov" } },
    },
    objdump = {
        { "-d", "init sections", { "-d" } },
        { "-D", "all sections", { "-D" } },
        { "-d -S", "source interleaved", { "-d", "-S" } },
    },
    gobjdump = {
        { "-d", "init sections", { "-d" } },
        { "-D", "all sections", { "-D" } },
    },
    r2 = {
        {
            "pda (deep)",
            "all functions, with XREF",
            { "-e", "scr.color=0", "-AAAA", "-q", "-c", "aa; aac; aar; aab; pda" },
        },
        {
            "pdf @@f",
            "per function, with XREF",
            { "-e", "scr.color=0", "-AAAA", "-q", "-c", "aa; aac; pdf @@f" },
        },
        {
            "pD $s",
            "whole file, no XREF",
            { "-e", "scr.color=0", "-q", "-c", "s 0; pD $s" },
        },
    },
}

local ALIAS = {
    radare2 = "r2",
    rizin = "r2",
}

local DESC = {
    ["llvm-objdump"] = "LLVM disassembler",
    otool = "Apple otool",
    objdump = "GNU binutils",
    gobjdump = "GNU binutils",
    r2 = "radare2",
    radare2 = "radare2",
    rizin = "rizin",
}

local function split(s) return vim.split(s, "%s+", { trimempty = true }) end
local function truncate(s, w)
    if vim.fn.strdisplaywidth(s) <= w then return s end
    return vim.fn.strcharpart(s, 0, math.max(1, w - 1)) .. "…"
end

local function scan()
    local tools, seen = {}, {}

    local function add(path, src)
        if not path or vim.fn.executable(path) ~= 1 then return end
        local real = vim.uv.fs_realpath(path) or path
        if seen[real] then return end
        seen[real] = true
        local name = vim.fn.fnamemodify(path, ":t")
        src = src
            or (path:match("/Cellar/") and "brew")
            or (path:match("/Xcode") and "Xcode")
            or (path:match("/CommandLineTools/") and "CLT")
            or "PATH"
        tools[#tools + 1] = {
            path = path,
            real = real,
            name = name,
            label = ("%s (%s)"):format(name, src),
            desc = DESC[name] or "",
            detail = path,
        }
    end

    local names = { "llvm-objdump", "otool", "r2", "radare2", "rizin" }
    if vim.fn.has("mac") == 0 then
        vim.list_extend(names, { "objdump", "gobjdump" })
    else
        local p = vim.fn.exepath("objdump")
        if p ~= "" and (p:match("/binutils") or p:match("/Cellar/binutils")) then add(p, "binutils") end
    end
    for _, n in ipairs(names) do
        add(vim.fn.exepath(n))
    end

    for _, prefix in ipairs({ "/opt/homebrew", "/usr/local" }) do
        for _, p in ipairs(vim.fn.glob(prefix .. "/opt/llvm*/bin/llvm-objdump", false, true)) do
            local ver = p:match("/opt/llvm@(%d+)/")
            add(p, ver and ("brew @%s"):format(ver) or "brew")
        end
        for _, n in ipairs({ "otool", "r2", "rizin" }) do
            for _, p in ipairs(vim.fn.glob(prefix .. "/opt/*/bin/" .. n, false, true)) do
                add(p, "brew")
            end
        end
    end

    for _, f in ipairs({
        {
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-objdump",
            "Xcode",
        },
        {
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/otool",
            "Xcode",
        },
        {
            "/Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-objdump",
            "Xcode-beta",
        },
        {
            "/Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/otool",
            "Xcode-beta",
        },
        { "/Library/Developer/CommandLineTools/usr/bin/llvm-objdump", "CLT" },
        { "/Library/Developer/CommandLineTools/usr/bin/otool", "CLT" },
    }) do
        add(f[1], f[2])
    end

    return tools
end

local function pick(items, opts)
    local on_choice, on_back = opts.on_choice, opts.on_back

    local max_label_w, max_desc_w = 0, 0
    for _, it in ipairs(items) do
        local lw = vim.fn.strdisplaywidth(it.label or "")
        local dw = vim.fn.strdisplaywidth(it.desc or "")
        if lw > max_label_w then max_label_w = lw end
        if dw > max_desc_w then max_desc_w = dw end
    end
    local label_col = max_label_w + 2
    local list_w = 5 + label_col + max_desc_w

    local hint = on_back and "<CR> select   <Esc> back   q close   ← → scroll path"
        or "<CR> select   <Esc> cancel   q close   ← → scroll path"
    local hint_w = vim.fn.strdisplaywidth(hint) + 6

    local min_w = math.floor(vim.o.columns / 2)
    local min_h = math.floor(vim.o.lines / 3)

    local width = math.min(math.max(list_w + 6, hint_w, 50, min_w), math.min(vim.o.columns - 4, 140))

    local max_rows = math.max(5, math.floor(vim.o.lines / 3))
    local list_h = math.min(#items, max_rows)
    local height = math.min(math.max(list_h + 1, min_h), vim.o.lines - 4)

    local row = math.floor((vim.o.lines - height - 2) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local desc_avail = width - 6 - label_col
    local row_lines = {}
    for i = 1, list_h do
        local it = items[i]
        if it then
            local label = truncate(it.label or "", label_col - 1)
            local lw = vim.fn.strdisplaywidth(label)
            local pad = string.rep(" ", math.max(1, label_col - lw))
            local desc = truncate(it.desc or "", desc_avail)
            row_lines[i] = string.format("%2d. %s%s%s", i, label, pad, desc)
        else
            row_lines[i] = ""
        end
    end

    local total_lines = {}
    for i = 1, height do
        total_lines[i] = row_lines[i] or ""
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, total_lines)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " " .. (opts.title or "Select") .. " ",
        title_pos = "center",
        footer = " " .. hint .. " ",
        footer_pos = "center",
    })
    vim.wo[win].wrap = false
    vim.wo[win].cursorline = true

    local ns = vim.api.nvim_create_namespace("pick_hl")
    vim.api.nvim_set_hl(0, "PickSel", { link = "Visual", default = true })
    vim.api.nvim_set_hl(0, "PickIdx", { link = "LineNr", default = true })
    vim.api.nvim_set_hl(0, "PickScrollHint", { fg = "#e0af68", bold = true, default = true })

    local scroll_off = 0

    local function current_line()
        local l = vim.api.nvim_win_get_cursor(win)[1]
        return math.max(1, math.min(l, list_h))
    end

    local function render()
        local line = current_line()

        vim.api.nvim_buf_clear_namespace(buf, ns, 0, list_h)
        for i = 1, list_h do
            vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_col = 2, hl_group = "PickIdx" })
        end
        local hl = row_lines[line] or ""
        if hl ~= "" then
            vim.api.nvim_buf_set_extmark(buf, ns, line - 1, 0, { end_col = #hl, hl_group = "PickSel", priority = 100 })
        end

        local detail = items[line] and items[line].detail or ""
        local total = vim.fn.strchars(detail)
        local max_w = width - 12
        local max_off = math.max(0, total - max_w)
        if scroll_off > max_off then scroll_off = max_off end
        if scroll_off < 0 then scroll_off = 0 end

        local visible = vim.fn.strcharpart(detail, scroll_off, max_w)
        local vis_len = vim.fn.strchars(visible)
        local has_left = scroll_off > 0
        local has_right = scroll_off + vis_len < total
        local lh = has_left and "%#PickScrollHint# <<< %*" or "     "
        local rh = has_right and " %#PickScrollHint#>>>%* " or "     "
        vim.wo[win].winbar = lh .. " " .. visible:gsub("%%", "%%%%") .. rh
    end

    local function close()
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end
    local function confirm()
        local it = items[current_line()]
        close()
        if it then on_choice(it) end
    end
    local function esc()
        close()
        if on_back then on_back() end
    end
    local function scroll(d)
        scroll_off = scroll_off + d
        render()
    end

    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = buf,
        callback = function()
            local raw = vim.api.nvim_win_get_cursor(win)[1]
            if raw < 1 or raw > list_h then
                vim.api.nvim_win_set_cursor(win, { math.max(1, math.min(raw, list_h)), 0 })
                return
            end
            scroll_off = 0
            render()
        end,
    })

    local km = vim.keymap.set
    km("n", "<Left>", function() scroll(-5) end, { buffer = buf })
    km("n", "<Right>", function() scroll(5) end, { buffer = buf })
    km("n", "<CR>", confirm, { buffer = buf })
    km("n", "<Esc>", esc, { buffer = buf })
    km("n", "q", close, { buffer = buf })

    vim.api.nvim_win_set_cursor(win, { 1, 0 })
    render()
end

local function preview(argv, label, on_accept, on_back)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "asm"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Loading…" })
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false

    local width = math.min(math.max(80, math.floor(vim.o.columns * 0.85)), 180)
    local height = math.min(math.max(20, math.floor(vim.o.lines * 0.85)), 60)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local footer = on_back and " <CR> accept   <Esc> back   q reject "

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " " .. label .. " ",
        title_pos = "center",
        footer = footer,
        footer_pos = "center",
    })
    vim.wo[win].wrap = false

    local proc, done, lines = nil, false, nil

    local function kill()
        if proc then
            pcall(function() proc:kill("sigterm") end)
            proc = nil
        end
    end
    local function close(go_back)
        if done then return end
        done = true
        kill()
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        if go_back and on_back then on_back() end
    end

    local km = vim.keymap.set
    km("n", "q", function() close(false) end, { buffer = buf })
    km("n", "<Esc>", function() close(true) end, { buffer = buf })
    km("n", "<CR>", function()
        if not lines then
            vim.notify("Still loading…", vim.log.levels.INFO)
            return
        end
        on_accept(lines)
        close(false)
    end, { buffer = buf })

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        once = true,
        callback = function()
            if done then return end
            done = true
            kill()
        end,
    })

    proc = vim.system(argv, { text = true }, function(res)
        vim.schedule(function()
            if done then return end
            proc = nil

            if res.code ~= 0 then
                vim.notify(
                    ("Disasm failed (%d): %s"):format(res.code, (res.stderr or ""):gsub("\n.*", "")),
                    vim.log.levels.WARN
                )
                close(true)
                return
            end
            if not vim.api.nvim_buf_is_valid(buf) then return end

            local raw = (res.stdout or ""):gsub("\27%[[%d;]*m", "")
            lines = vim.split(raw, "\n", { plain = true })
            while #lines > 0 and lines[#lines]:match("^%s*$") do
                table.remove(lines)
            end
            if #lines == 0 then
                vim.notify("Empty output", vim.log.levels.WARN)
                close(true)
                return
            end

            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].modifiable = false
            vim.bo[buf].modified = false

            vim.api.nvim_win_set_config(win, { title = (" %s ( %d lines ) "):format(label, #lines) })
        end)
    end)
end

local last_tool, last_mode, last_custom

function M.run(path, on_accept)
    local open_tool, open_option

    local function exec(tool, flags, mode_label)
        local argv = { tool.path }
        vim.list_extend(argv, flags)
        argv[#argv + 1] = path
        preview(argv, ("%s — %s"):format(tool.name, mode_label), on_accept, function() open_option(tool) end)
    end

    open_option = function(tool)
        local presets = PRESETS[ALIAS[tool.name] or tool.name] or {}
        local items = {}

        for i, p in ipairs(presets) do
            items[#items + 1] = {
                label = p[1],
                desc = p[2],
                detail = ("%s %s"):format(tool.path, p[3]),
                idx = i,
                flags = p[3],
            }
        end

        if last_mode and items[last_mode] then
            local t = table.remove(items, last_mode)
            table.insert(items, 1, t)
            t.label = "★  " .. t.label
        end

        items[#items + 1] = {
            label = "✎ Custom flags…",
            desc = nil,
            detail = ("%s <flags>"):format(tool.path),
            custom = true,
        }

        pick(items, {
            title = tool.label .. " — options",
            on_back = open_tool,
            on_choice = function(choice)
                if choice.custom then
                    vim.ui.input({ prompt = "Flags: " }, function(input)
                        if input == nil then return end
                        exec(tool, split(input), input ~= "" and input or "default")
                    end)
                else
                    last_mode = choice.idx
                    exec(tool, choice.flags, choice.label)
                end
            end,
        })
    end

    open_tool = function()
        local tools = scan()

        if #tools == 0 then
            vim.notify("No disassembler found", vim.log.levels.WARN)
            return
        end

        if last_tool then
            for i, t in ipairs(tools) do
                if t.real == last_tool then
                    local it = table.remove(tools, i)
                    table.insert(tools, 1, it)
                    it.label = "★  " .. it.label
                    break
                end
            end
        end

        tools[#tools + 1] = {
            label = "✎ Custom command…",
            desc = "denote {} = file path",
            detail = "custom",
            custom = true,
        }

        pick(tools, {
            title = "Disassembler",
            on_choice = function(tool)
                if tool.custom then
                    vim.ui.input({
                        prompt = "Command ({} = file path): ",
                        default = last_custom or "",
                    }, function(input)
                        if not input or input == "" then return end
                        last_custom = input
                        local s = input:find("{}", 1, true) and input:gsub("{}", vim.fn.shellescape(path))
                            or (input .. " " .. vim.fn.shellescape(path))
                        preview({ "sh", "-c", s }, "custom: " .. input, on_accept, nil)
                    end)
                    return
                end
                last_tool = tool.real
                open_option(tool)
            end,
        })
    end

    open_tool()
end

return M
