return {
    {
        "folke/snacks.nvim",

        opts = function(_, opts)
            opts.image = opts.image or {}

            opts.image.enabled = true
            opts.image.doc = opts.image.doc or {}
            opts.image.doc.enabled = true
            opts.image.doc.inline = true

            opts.image.math = opts.image.math or {}
            opts.image.math.enabled = false

            local current_formats = opts.image.formats
                or {
                    "png",
                    "jpg",
                    "jpeg",
                    "gif",
                    "bmp",
                    "webp",
                    "tiff",
                    "heic",
                    "avif",
                    "mp4",
                    "mov",
                    "avi",
                    "mkv",
                    "webm",
                    "pdf",
                    "icns",
                }
            local new_formats = {}
            for _, ext in ipairs(current_formats) do
                if ext ~= "pdf" then new_formats[#new_formats + 1] = ext end
            end
            opts.image.formats = new_formats

            return opts
        end,
    },
}
