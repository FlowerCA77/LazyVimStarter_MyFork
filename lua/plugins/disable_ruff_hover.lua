return {
    {
        "neovim/nvim-lspconfig",
        opts = function(_, opts)
            opts.servers["ruff"] = vim.tbl_deep_extend("force", opts.servers["ruff"] or {}, {
                on_attach = function(client) client.server_capabilities.hoverProvider = false end,
            })
        end,
    },
}
