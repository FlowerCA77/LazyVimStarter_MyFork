local M = {}

function M.config()
    do
        local ok, snacks = pcall(require, "snacks")
        if not ok or not snacks.image or not snacks.image.config then return end

        local formats = snacks.image.config.formats
        if not formats or #formats == 0 then return end

        local pattern = {}
        for _, ext in ipairs(formats) do
            pattern[#pattern + 1] = "*." .. ext
        end

        local sid_group = vim.api.nvim_create_augroup("SnacksImageDestroyer", { clear = true })

        vim.api.nvim_create_autocmd("BufLeave", {
            group = sid_group,
            pattern = pattern,
            callback = function(args)
                local function is_buf_displayed(buf)
                    for _, win in ipairs(vim.api.nvim_list_wins()) do
                        if vim.api.nvim_win_get_buf(win) == buf then return true end
                    end
                    return false
                end

                vim.schedule(function()
                    local b = args.buf
                    if not vim.api.nvim_buf_is_valid(b) then return end
                    if vim.api.nvim_get_current_buf() == b then return end
                    if is_buf_displayed(b) then return end
                    pcall(vim.api.nvim_buf_delete, b, { force = true })
                end)
            end,
        })
    end
end

return M
