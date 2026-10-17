local M = {}

local disasm = require("config.autocmds.disassembly.disasm_impl")

function M.config()
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
end

return M
