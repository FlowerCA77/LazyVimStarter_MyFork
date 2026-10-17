local M = {}

function M.config()
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
end

return M
