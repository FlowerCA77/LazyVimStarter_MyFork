return {
    {
        "folke/snacks.nvim",
        init = function()
            local ipynb = require("config.ipynb-preview")
            vim.api.nvim_create_user_command("NbPreview", ipynb.preview, {})
        end,
    },
}
