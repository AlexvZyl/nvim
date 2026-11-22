local git = require("review.git")

local M = {}

local namespace = vim.api.nvim_create_namespace("review")
local deleted_namespace = vim.api.nvim_create_namespace("review_deleted")
local buffer_hunks = {}
local SIGN = "▏"

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

local function highlight_deleted(lang, hunk)
    hunk.highlights = {}
    local query = lang and vim.treesitter.query.get(lang, "highlights")
    if not query or #hunk.deleted == 0 then
        return
    end
    local source = table.concat(hunk.deleted, "\n")
    local ok, parser = pcall(vim.treesitter.get_string_parser, source, lang)
    if not ok then
        return
    end
    for id, node in query:iter_captures(parser:parse()[1]:root(), source) do
        local name = query.captures[id]
        if not name:find("^_") and name ~= "spell" and name ~= "nospell" then
            local start_row, start_col, end_row, end_col = node:range()
            for row = start_row, math.min(end_row, #hunk.deleted - 1) do
                local line = hunk.highlights[row + 1] or {}
                hunk.highlights[row + 1] = line
                local last = row == end_row and end_col or #hunk.deleted[row + 1]
                for col = (row == start_row and start_col or 0) + 1, last do
                    line[col] = "@" .. name .. "." .. lang
                end
            end
        end
    end
end

local function deleted_chunks(text, highlights, leftcol, tabstop)
    local chunks, shown, byte = {}, 0, 1
    for char in text:gmatch("[^\128-\191][\128-\191]*") do
        local group = highlights[byte] and { "ReviewDelete", highlights[byte] } or "ReviewDelete"
        byte = byte + #char
        for _ = 1, char == "\t" and tabstop or 1 do
            shown = shown + 1
            if shown > leftcol then
                local last = chunks[#chunks]
                if last and last[2] == group then
                    last[1] = last[1] .. (char == "\t" and " " or char)
                else
                    table.insert(chunks, { char == "\t" and " " or char, group })
                end
            end
        end
    end
    table.insert(chunks, { string.rep(" ", math.max(vim.o.columns - shown + leftcol, 0)), "ReviewDelete" })
    return chunks
end

local function render_deleted(buf)
    vim.api.nvim_buf_clear_namespace(buf, deleted_namespace, 0, -1)
    local win = vim.fn.win_findbuf(buf)[1] or vim.api.nvim_get_current_win()
    local textoff = vim.fn.getwininfo(win)[1].textoff
    local leftcol = vim.api.nvim_win_call(win, vim.fn.winsaveview).leftcol
    local gutter = SIGN .. string.rep(" ", textoff - 2)
    local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
    for _, hunk in ipairs(buffer_hunks[buf] or {}) do
        if not hunk.highlights then
            highlight_deleted(lang, hunk)
        end
        if #hunk.deleted > 0 then
            local virt_lines = {}
            for i, text in ipairs(hunk.deleted) do
                local line = { { " ", "LineNr" }, { gutter, "ReviewSignDelete" } }
                vim.list_extend(line, deleted_chunks(text, hunk.highlights[i] or {}, leftcol, vim.bo[buf].tabstop))
                table.insert(virt_lines, line)
            end
            vim.api.nvim_buf_set_extmark(buf, deleted_namespace, math.max(hunk.start - 1, 0), 0, {
                virt_lines = virt_lines,
                virt_lines_above = hunk.count > 0 or hunk.start == 0,
                virt_lines_leftcol = true,
            })
        end
    end
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
                    number_hl_group = "ReviewAddNr",
                    sign_text = SIGN,
                    sign_hl_group = "ReviewSignAdd",
                })
            end
        end
    end
    render_deleted(buf)
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
    if #hunks == 0 then
        -- Not part of the diff (anymore), drop anything from a previous attach.
        if buffer_hunks[buf] then
            buffer_hunks[buf] = nil
            vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
            vim.api.nvim_buf_clear_namespace(buf, deleted_namespace, 0, -1)
            pcall(vim.keymap.del, "n", "]h", { buffer = buf })
            pcall(vim.keymap.del, "n", "[h", { buffer = buf })
        end
        return
    end
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

function M.scrolled()
    for win, delta in pairs(vim.v.event) do
        local id = tonumber(win)
        if id and delta.leftcol ~= 0 and vim.api.nvim_win_is_valid(id) then
            local buf = vim.api.nvim_win_get_buf(id)
            if buffer_hunks[buf] then
                render_deleted(buf)
            end
        end
    end
end

function M.first_hunk(buf)
    return (buffer_hunks[buf] or {})[1]
end

return M
