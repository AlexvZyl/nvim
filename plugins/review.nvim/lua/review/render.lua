local git = require("review.git")

local M = {}

local namespace = vim.api.nvim_create_namespace("review")
local deleted_namespace = vim.api.nvim_create_namespace("review_deleted")
local buffer_hunks = {}
local sources = {}
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

local function render(buf, hunks)
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    for _, hunk in ipairs(hunks) do
        for line = hunk.start, hunk.start + hunk.count - 1 do
            vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
                line_hl_group = "ReviewAdd",
                number_hl_group = "ReviewAddNr",
                sign_text = SIGN,
                sign_hl_group = "ReviewSignAdd",
            })
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

local function buffer_text(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if #lines == 1 and lines[1] == "" then
        return ""
    end
    return table.concat(lines, "\n") .. "\n"
end

local function diff(from, to)
    return parse_hunks(vim.text.diff(from, to, { ctxlen = 0, indent_heuristic = true }) or "")
end

local function detach(buf)
    if not buffer_hunks[buf] then
        return
    end
    buffer_hunks[buf] = nil
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, deleted_namespace, 0, -1)
    pcall(vim.keymap.del, "n", "]h", { buffer = buf })
    pcall(vim.keymap.del, "n", "[h", { buffer = buf })
end

-- Diffs the buffer against the merge base in memory, so edits show up while typing.
function M.update(buf, defer)
    local source = sources[buf]
    if not source or not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local text = buffer_text(buf)
    local hunks = diff(source.base, text)
    if #hunks == 0 then
        return detach(buf)
    end
    -- Treesitter highlights of deleted lines only change when the deleted text does.
    local cached = {}
    for _, hunk in ipairs(buffer_hunks[buf] or {}) do
        cached[table.concat(hunk.deleted, "\n")] = hunk.highlights
    end
    for _, hunk in ipairs(hunks) do
        hunk.highlights = cached[table.concat(hunk.deleted, "\n")]
    end
    if not buffer_hunks[buf] then
        vim.keymap.set("n", "]h", function()
            jump(buffer_hunks[buf] or {}, true)
        end, { buffer = buf })
        vim.keymap.set("n", "[h", function()
            jump(buffer_hunks[buf] or {}, false)
        end, { buffer = buf })
    end
    buffer_hunks[buf] = hunks
    if not defer then
        return render(buf, hunks)
    end
    vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) and buffer_hunks[buf] == hunks then
            render(buf, hunks)
        end
    end)
end

function M.attach(buf)
    local file = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype ~= "" or vim.fn.filereadable(file) == 0 then
        return
    end
    local merge_base = git.merge_base()
    local base = merge_base ~= "" and git.show(merge_base, file) or nil
    local head = git.show("HEAD", file)
    local binary = (base or ""):find("\0", 1, true) or (head or ""):find("\0", 1, true)
    if (not base and not head) or binary then
        -- Untracked, outside the repo or binary.
        sources[buf] = nil
        return detach(buf)
    end
    sources[buf] = { base = base or "" }
    M.update(buf, true)
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
