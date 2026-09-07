return {
    {
        "neovim/nvim-lspconfig",
        ---@class PluginLspOpts
        opts = {
            servers = {
                tinymist = {
                    -- WARNING: notice that |lsp-root_dir| is
                    -- lsp-root_dir: string | fun(bufnr: integer, on_dir: fun(root_dir?: string))
                    -- not
                    -- lsp-root_dir: string | fun(fname: string)
                    root_markers = { ".git", "typst.toml", "main.typ" },
                    single_file_support = true,

                    settings = {
                        formatterMode = "typstyle",
                        formatterProseWrap = true,
                        formatterPrintWidth = 120,
                        formatterIndentSize = 4,
                    },

                    on_attach = function(client, bufnr)
                        vim.keymap.set("n", "<leader>tp", function()
                            client:exec_cmd({
                                title = "pin",
                                command = "tinymist.pinMain",
                                arguments = { vim.api.nvim_buf_get_name(0) },
                            }, { bufnr = bufnr })
                        end, {
                            desc = "[T]inymist [P]in",
                            noremap = true,
                        })

                        vim.keymap.set("n", "<leader>tu", function()
                            client:exec_cmd({
                                title = "unpin",
                                command = "tinymist.pinMain",
                                arguments = { vim.v.null },
                            }, { bufnr = bufnr })
                        end, {
                            desc = "[T]inymist [U]npin",
                            noremap = true,
                        })
                    end,
                },
            },
        },
    },
}
