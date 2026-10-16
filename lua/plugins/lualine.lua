return {
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",

        opts = function(_, opts)
            -- Helper function to get active LSP clients for the current buffer
            local function lsp_clients()
                local bufnr = vim.api.nvim_get_current_buf()
                local clients = vim.lsp.get_clients({ bufnr = bufnr })

                if next(clients) == nil then return "No LSP" end

                local c = {}

                for _, client in pairs(clients) do
                    table.insert(c, client.name)
                end

                return "LSP: " .. table.concat(c, "|")
            end

            table.insert(opts.sections.lualine_x, 2, { lsp_clients })
        end,
    },
}
