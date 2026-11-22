local config = require("review.config")
local session = require("review.session")

local M = {}

local function guarded(fn)
    return function(...)
        if not session.active() then
            return vim.notify("Not in diff mode", vim.log.levels.WARN)
        end
        fn(...)
    end
end

function M.active()
    return session.active()
end

M.panel = guarded(function()
    require("review.panel").toggle()
end)

M.reset = guarded(function()
    local panel = require("review.panel")
    if not session.load() then
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

function M.setup(opts)
    config.set(opts)
    if vim.fn.argv(0) ~= "diff" then
        return
    end

    -- A failing callback would error on every event, stop review on the first one instead.
    local group = vim.api.nvim_create_augroup("review", { clear = true })
    local function autocmd(event, opts)
        local callback = opts.callback
        opts.group = group
        opts.callback = function(args)
            local ok, err = pcall(callback, args)
            if not ok then
                pcall(vim.api.nvim_del_augroup_by_id, group)
                vim.schedule(function()
                    vim.notify("review.nvim stopped after an error, restart to resume:\n" .. err, vim.log.levels.ERROR)
                end)
            end
        end
        vim.api.nvim_create_autocmd(event, opts)
    end

    set_highlights()
    autocmd("ColorScheme", { callback = set_highlights })
    session.start(vim.fn.argc() > 1 and vim.fn.argv(1) or config.options.base)
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
    autocmd("BufEnter", {
        callback = function(args)
            require("review.panel").follow(args.buf)
        end,
    })
    autocmd("WinScrolled", {
        callback = function()
            require("review.render").scrolled()
        end,
    })
    autocmd({ "BufReadPost", "BufWritePost" }, {
        callback = function(args)
            require("review.render").attach(args.buf)
        end,
    })
    autocmd("BufWipeout", {
        callback = function(args)
            require("review.render").detach(args.buf)
        end,
    })
    autocmd({ "TextChanged", "TextChangedI" }, {
        callback = function(args)
            require("review.render").update(args.buf)
        end,
    })

    -- Gitsigns draws over the review signs, turn it off once it is set up.
    local function disable_gitsigns()
        if not package.loaded.gitsigns then
            return
        end
        local gitsigns = require("gitsigns")
        for _, toggle in ipairs({ "toggle_signs", "toggle_numhl", "toggle_linehl", "toggle_word_diff", "toggle_deleted" }) do
            if gitsigns[toggle] then
                pcall(gitsigns[toggle], false)
            end
        end
    end
    autocmd("VimEnter", { once = true, callback = disable_gitsigns })
    autocmd("User", {
        pattern = "LazyLoad",
        callback = function(args)
            if args.data == "gitsigns.nvim" then
                vim.schedule(disable_gitsigns)
            end
        end,
    })
end

return M
