local git = require("alex.native.review.git")

local M = {}

local namespace = vim.api.nvim_create_namespace("review")
local buffer_hunks = {}
local SIGN = "│"

local function parse_hunks(patch)
    local hunks = {}
    local current
    for _, line in ipairs(vim.split(patch, "\n", { plain = true })) do
        local start, count = line:match("^@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
        if start then
            current = {
                start = tonumber(start),
                count = count == "" and 1 or tonumber(count),
                deleted = {},
            }
            table.insert(hunks, current)
        elseif current and line:sub(1, 1) == "-" then
            table.insert(current.deleted, line:sub(2))
        end
    end
    return hunks
end

local function deleted_virt_lines(buf, deleted)
    local tab = string.rep(" ", vim.bo[buf].tabstop)
    local win = vim.fn.win_findbuf(buf)[1] or vim.api.nvim_get_current_win()
    local textoff = vim.fn.getwininfo(win)[1].textoff
    local gutter = " " .. SIGN .. string.rep(" ", textoff - 2)
    local virt_lines = {}
    for _, text in ipairs(deleted) do
        text = text:gsub("\t", tab)
        local padded = text .. string.rep(" ", math.max(vim.o.columns - #text, 0))
        table.insert(virt_lines, { { gutter, "ReviewSignDelete" }, { padded, "ReviewDelete" } })
    end
    return virt_lines
end

local function render(buf, hunks, local_hunks)
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    local local_lines = {}
    for _, hunk in ipairs(local_hunks) do
        local last = math.max(hunk.start + hunk.count - 1, hunk.start)
        for line = math.max(hunk.start, 1), last do
            local_lines[line] = true
            vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
                sign_text = SIGN,
                sign_hl_group = "ReviewSignLocal",
            })
        end
    end
    for _, hunk in ipairs(hunks) do
        for line = hunk.start, hunk.start + hunk.count - 1 do
            if not local_lines[line] then
                vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
                    line_hl_group = "ReviewAdd",
                    sign_text = SIGN,
                    sign_hl_group = "ReviewSignAdd",
                })
            end
        end
        if #hunk.deleted > 0 then
            vim.api.nvim_buf_set_extmark(buf, namespace, math.max(hunk.start - 1, 0), 0, {
                virt_lines = deleted_virt_lines(buf, hunk.deleted),
                virt_lines_above = hunk.count > 0 or hunk.start == 0,
                virt_lines_leftcol = true,
            })
        end
    end
end

local function jump(hunks, forward)
    local current = vim.api.nvim_win_get_cursor(0)[1]
    local target
    for _, hunk in ipairs(hunks) do
        local line = math.max(hunk.start, 1)
        if forward and line > current then
            target = target or line
        elseif not forward and line < current then
            target = line
        end
    end
    if target then
        vim.api.nvim_win_set_cursor(0, { target, 0 })
    end
end

function M.attach(buf)
    local file = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype ~= "" or vim.fn.filereadable(file) == 0 then
        return
    end
    local patch = git.diff("-U0", "--", file)
    if not patch then
        return
    end
    local hunks = parse_hunks(patch)
    buffer_hunks[buf] = hunks
    local local_hunks = parse_hunks(git.run("diff", "-U0", "HEAD", "--", file) or "")
    vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then
            return
        end
        render(buf, hunks, local_hunks)
    end)
    vim.keymap.set("n", "]h", function()
        jump(hunks, true)
    end, { buffer = buf })
    vim.keymap.set("n", "[h", function()
        jump(hunks, false)
    end, { buffer = buf })
end

function M.first_hunk(buf)
    return (buffer_hunks[buf] or {})[1]
end

return M
