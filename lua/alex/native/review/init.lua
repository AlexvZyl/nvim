local git = require("alex.native.review.git")
local session = require("alex.native.review.session")

local M = {}

local function guarded(fn)
    return function()
        if not session.ref then
            return vim.notify("Not in diff mode", vim.log.levels.WARN)
        end
        fn()
    end
end

function M.active()
    return session.ref ~= nil
end

M.panel = guarded(function()
    require("alex.native.review.panel").toggle()
end)

M.files = guarded(function()
    require("telescope")
    local templates = require("alex.plugins.telescope")
    require("telescope.builtin").find_files(vim.tbl_extend("force", templates.large_no_preview, {
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
    local panel = require("alex.native.review.panel")
    if not git.load() then
        return
    end
    require("alex.native.review.state").reset()
    if panel.is_open() then
        panel.close()
        panel.toggle()
    end
end)

function M.setup()
    if vim.fn.argv(0) ~= "diff" then
        return
    end
    session.ref = vim.fn.argc() > 1 and vim.fn.argv(1) or "dev"
    vim.cmd("%argdelete")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf ~= vim.api.nvim_get_current_buf() then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
    vim.api.nvim_buf_set_name(0, "")

    vim.api.nvim_create_user_command("ReviewReset", M.reset, {})
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        callback = function(args)
            require("alex.native.review.render").attach(args.buf)
        end,
    })
end

return M
