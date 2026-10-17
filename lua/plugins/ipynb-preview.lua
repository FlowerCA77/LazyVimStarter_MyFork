local function find_nbconvert()
    for _, name in ipairs({ "jupyter-nbconvert", "nbconvert" }) do
        local p = vim.fn.exepath(name)
        if p ~= "" and vim.fn.executable(p) == 1 then return p end
    end
    for _, name in ipairs({ "jupyter-nbconvert", "nbconvert" }) do
        local fb = vim.fn.expand("~/.local/bin/" .. name)
        if vim.fn.executable(fb) == 1 then return fb end
    end
    return nil
end

local function preview()
    local src = vim.api.nvim_buf_get_name(0)
    if not src:match("%.ipynb$") then
        vim.notify("Not an ipynb buffer", vim.log.levels.WARN)
        return
    end

    local nbconvert = find_nbconvert()
    if nbconvert == nil then
        vim.notify("cannot find jupyter-nbconvert / nbconvert", vim.log.levels.ERROR)
        return
    end

    local stem = vim.fn.fnamemodify(src, ":t:r")
    local outdir, err, err_name = vim.uv.fs_mkdtemp(
        string.format(
            "%s/%s-%s-%d-ipynb-XXXXXX",
            vim.uv.os_tmpdir() or "/tmp",
            stem,
            os.date("%Y%m%d-%H%M%S"),
            vim.fn.getpid()
        )
    )

    if outdir == nil then
        vim.notify(
            string.format("cannot create tmpdir: %s (%s)", tostring(err), tostring(err_name)),
            vim.log.levels.ERROR
        )
        return
    end

    local out = vim.fn.system({
        nbconvert,
        "--to",
        "markdown",
        "--output-dir",
        outdir,
        src,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("nbconvert failed:\n" .. out, vim.log.levels.ERROR)
        return
    end

    local md_path = outdir .. "/" .. stem .. ".md"
    if vim.fn.filereadable(md_path) == 0 then
        vim.notify("md not found: " .. md_path, vim.log.levels.ERROR)
        return
    end

    local lines = vim.fn.readfile(md_path)
    for i, line in ipairs(lines) do
        lines[i] = line:gsub("%]%(([^)]+)%)", function(p)
            if p:match("^/") or p:match("^%a[%w+.-]*://") then return "](" .. p .. ")" end
            return "](" .. outdir .. "/" .. p .. ")"
        end)
    end

    vim.cmd("enew")

    local buf = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

    vim.bo.buftype = ""
    vim.bo.bufhidden = "hide"
    vim.bo.swapfile = false

    vim.api.nvim_buf_set_name(buf, "ipynb://" .. "/" .. stem)

    vim.bo.modified = false
    vim.bo.modifiable = false
    vim.bo.readonly = true

    vim.api.nvim_exec_autocmds("BufReadPre", { buffer = buf })
    vim.bo.filetype = "markdown"
end

return {
    {
        "folke/snacks.nvim",
        init = function() vim.api.nvim_create_user_command("NbPreview", preview, {}) end,
    },
}
