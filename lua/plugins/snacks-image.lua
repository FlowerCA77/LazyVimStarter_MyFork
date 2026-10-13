return {
    {
        "folke/snacks.nvim",

        opts = function(_, opts)
            local image_cfg = require("snacks.image").config or {}

            image_cfg.enabled = true

            image_cfg.doc.inline = false
            image_cfg.math.enabled = false

            opts.image = image_cfg
            return opts
        end,
    },
}
