local git = require("review.git")
local session = require("review.session")

local M = {}

local function guarded(fn)
    return function(...)
        if not session.ref then
            return vim.notify("Not in diff mode", vim.log.levels.WARN)
        end
        fn(...)
    end
end

function M.active()
    return session.ref ~= nil
end

M.panel = guarded(function()
    require("review.panel").toggle()
end)

M.files = guarded(function(opts)
    require("telescope")
    require("telescope.builtin").find_files(vim.tbl_extend("force", opts or {}, {
        prompt_title = "Review files",
        find_command = {
            "git",
            "-c",
            "core.quotePath=false",
            "diff",
            "--name-only",
            "--relative",
            "--diff-filter=d",
            "--no-renames",
            "--merge-base",
            session.ref,
        },
    }))
end)

M.reset = guarded(function()
    local panel = require("review.panel")
    if not git.load() then
        return
    end
    require("review.state").reset()
    if panel.is_open() then
        panel.close()
        panel.toggle()
    end
end)

local highlights = {
    ReviewAdd = "DiffAdd",
    ReviewAddNr = "DiffAdd",
    ReviewDelete = "DiffDelete",
    ReviewSignAdd = "Added",
    ReviewSignLocal = "Changed",
    ReviewSignDelete = "Removed",
    ReviewPanelLine = "CursorLine",
    ReviewPanelDir = "Directory",
    ReviewPanelNr = "CursorLineNr",
    ReviewChanged = "Changed",
    ReviewNew = "Added",
}

local function set_highlights()
    for group, link in pairs(highlights) do
        vim.api.nvim_set_hl(0, group, { link = link, default = true })
    end
end

function M.setup()
    if vim.fn.argv(0) ~= "diff" then
        return
    end
    set_highlights()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlights })
    session.ref = vim.fn.argc() > 1 and vim.fn.argv(1) or "dev"
    vim.cmd("%argdelete")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf ~= vim.api.nvim_get_current_buf() then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
    vim.api.nvim_buf_set_name(0, "")
    -- Renaming keeps the old name as the alternate buffer.
    local alternate = vim.fn.bufnr("#")
    if alternate ~= -1 and alternate ~= vim.api.nvim_get_current_buf() then
        vim.api.nvim_buf_delete(alternate, { force = true })
    end

    vim.api.nvim_create_user_command("ReviewReset", M.reset, {})
    vim.api.nvim_create_autocmd("BufEnter", {
        callback = function(args)
            require("review.panel").follow(args.buf)
        end,
    })
    vim.api.nvim_create_autocmd("WinScrolled", {
        callback = function()
            require("review.render").scrolled()
        end,
    })
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        callback = function(args)
            require("review.render").attach(args.buf)
        end,
    })
end

return M
