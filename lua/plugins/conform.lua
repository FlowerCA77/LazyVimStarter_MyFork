return {
    "stevearc/conform.nvim",
    opts = function(_, opts)
        opts.formatters = opts.formatters or {}
        opts.formatters_by_ft = opts.formatters_by_ft or {}

        opts.formatters_by_ft.json = { "fixjson" }
        opts.formatters.fixjson = { prepend_args = { "-i", "4" } }

        return opts
    end,
}
