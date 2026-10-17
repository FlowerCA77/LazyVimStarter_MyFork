local M = {}

function M.config()
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
end

return M
