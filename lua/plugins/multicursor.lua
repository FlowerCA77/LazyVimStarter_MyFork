return {
    {
        "jake-stewart/multicursor.nvim",
        branch = "1.0",
        config = function()
            local mc = require("multicursor-nvim")
            mc.setup()

            local map = vim.keymap.set

            -- Add cursors on adjacent lines.
            map({ "n", "x" }, "<leader>m<Up>", function() mc.lineAddCursor(-1) end, { desc = "MC: Add cursor above" })

            map({ "n", "x" }, "<leader>m<Down>", function() mc.lineAddCursor(1) end, { desc = "MC: Add cursor below" })

            -- Add cursors at matching occurrences.
            map(
                { "n", "x" },
                "<leader>mn",
                function() mc.matchAddCursor(1) end,
                { desc = "MC: Add next matching cursor" }
            )

            map(
                { "n", "x" },
                "<leader>mN",
                function() mc.matchAddCursor(-1) end,
                { desc = "MC: Add previous matching cursor" }
            )

            map({ "n", "x" }, "<leader>mA", mc.matchAllAddCursors, { desc = "MC: Add cursors at all matches" })

            -- Operator: e.g. gaip adds a cursor on each line of a paragraph.
            map({ "n", "x" }, "ga", mc.addCursorOperator, { desc = "MC: Add cursors by motion" })

            -- Insert/append at each visual selection.
            map("x", "I", mc.insertVisual)
            map("x", "A", mc.appendVisual)

            -- Mouse support.
            map("n", "<C-LeftMouse>", mc.handleMouse)
            map("n", "<C-LeftDrag>", mc.handleMouseDrag)
            map("n", "<C-LeftRelease>", mc.handleMouseRelease)

            -- Keymaps active only when multiple cursors exist.
            mc.addKeymapLayer(function(layerSet)
                -- Switch the primary cursor.
                layerSet({ "n", "x" }, "<leader><Left>", mc.prevCursor)
                layerSet({ "n", "x" }, "<leader><Right>", mc.nextCursor)

                -- Delete the primary cursor.
                layerSet({ "n", "x" }, "<leader>mx", mc.deleteCursor)

                -- Clear all cursors, or re-enable disabled cursors.
                layerSet("n", "<Esc>", function()
                    if not mc.cursorsEnabled() then
                        mc.enableCursors()
                    else
                        mc.clearCursors()
                    end
                end)
            end)

            -- Highlight groups.
            local hl = vim.api.nvim_set_hl
            hl(0, "MultiCursorCursor", { reverse = true })
            hl(0, "MultiCursorVisual", { link = "Visual" })
            hl(0, "MultiCursorSign", { link = "SignColumn" })
            hl(0, "MultiCursorMatchPreview", { link = "Search" })
            hl(0, "MultiCursorDisabledCursor", { reverse = true })
            hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
            hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
        end,
    },
}
