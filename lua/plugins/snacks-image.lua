return {
    {
        "folke/snacks.nvim",

        opts = function(_, opts)
            local image_cfg = require("snacks.image").config or {}

            if image_cfg.formats then
                image_cfg.formats = vim.tbl_filter(function(f)
                    return f ~= "pdf"
                end, image_cfg.formats)
            end

            image_cfg.enabled = true

            image_cfg.doc.inline = false
            image_cfg.math.enabled = false

            opts.image = image_cfg
            return opts
        end,
    },
}
