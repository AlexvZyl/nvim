-- Buffer is an open buffer of a reviewed file: its Files at the base and HEAD, its Diffs against them, and their drawing.
local config = require("review.config")
local scroll = require("review.scroll")
local review_file = require("review.file")
local syntax = require("review.syntax")

local Text, Diff = review_file.Text, review_file.Diff

local Buffer = {}
Buffer.__index = Buffer

local deleted_namespace = vim.api.nvim_create_namespace("review_deleted")

-- Drawing

Buffer.namespace = vim.api.nvim_create_namespace("review")

-- By group name. Marks take ids faster than names.
local hl_ids = setmetatable({}, {
    __index = function(ids, name)
        ids[name] = vim.api.nvim_get_hl_id_by_name(name)
        return ids[name]
    end,
})

local function sign_text(uncommitted)
    return config.options.signs[uncommitted and "uncommitted" or "committed"]
end

-- Kind is Add or Delete.
function Buffer.sign(bufnr, first_line, last_line, uncommitted, kind)
    local group = "Review" .. (uncommitted and "Local" or "") .. kind
    vim.api.nvim_buf_set_extmark(bufnr, Buffer.namespace, first_line - 1, 0, {
        end_row = last_line - 1,
        line_hl_group = group,
        number_hl_group = group .. "Nr",
        sign_text = sign_text(uncommitted),
        sign_hl_group = "ReviewSign" .. group:sub(7),
        priority = config.options.sign_priority,
    })
end

-- The number and sign columns as chunks, for virtual lines.
local function gutter_chunks(gutter_width, uncommitted, kind)
    local text = sign_text(uncommitted)
    local sign = text .. string.rep(" ", gutter_width - 1 - vim.fn.strdisplaywidth(text))
    return { { " ", hl_ids.LineNr }, { sign, hl_ids["ReviewSign" .. (uncommitted and "Local" or "") .. kind] } }
end

-- A deleted line as chunks: highlighted by byte, scrolled by leftcol and padded to the window's edge.
local function deleted_text_chunks(text, highlights, uncommitted, leftcol, tabstop)
    local group = uncommitted and "ReviewLocalDelete" or "ReviewDelete"
    local line_id, background_id = hl_ids[group], hl_ids[group .. "Background"]
    local chunks, width, last_group = {}, 0, nil
    -- Merges neighbours with the same highlight.
    local function add(part, part_group)
        if chunks[1] and part_group == last_group then
            chunks[#chunks][1] = chunks[#chunks][1] .. part
        else
            table.insert(chunks, { part, part_group and { line_id, hl_ids[part_group], background_id } or line_id })
        end
        last_group = part_group
    end
    -- Start of the current run of visible bytes. A byte loop, as the JIT does not compile gmatch.
    local run_start, byte = nil, 1
    while byte <= #text do
        local byte_group, code = highlights[byte], text:byte(byte)
        -- Skips UTF-8 continuation bytes.
        local next_char = byte + 1
        while (text:byte(next_char) or 0) >= 128 and text:byte(next_char) < 192 do
            next_char = next_char + 1
        end
        local cells = code == 9 and tabstop - width % tabstop
            or code < 128 and 1
            or vim.api.nvim_strwidth(text:sub(byte, next_char - 1))
        width = width + cells
        local visible_cells = math.min(cells, width - leftcol)
        -- Tabs, and wide characters cut by the window edge (as <), are drawn as blanks.
        local blank = visible_cells > 0 and (code == 9 or visible_cells < cells)
        if run_start and (blank or byte_group ~= highlights[run_start]) then
            add(text:sub(run_start, byte - 1), highlights[run_start])
            run_start = nil
        end
        if blank then
            add(code == 9 and string.rep(" ", visible_cells) or "<" .. string.rep(" ", visible_cells - 1), byte_group)
        elseif visible_cells > 0 then
            run_start = run_start or byte
        end
        byte = next_char
    end
    if run_start then
        add(text:sub(run_start), highlights[run_start])
    end
    table.insert(chunks, { string.rep(" ", math.max(vim.o.columns - width + leftcol, 0)), line_id })
    return chunks
end

-- Buffers

-- For files git does not have at a revision.
local EMPTY = Text.new("")

local function text_of(file)
    return file and file.text or EMPTY
end

-- By buffer number.
local attached = {}

function Buffer.get(bufnr)
    return attached[bufnr]
end

function Buffer.each()
    return pairs(attached)
end

function Buffer.new(bufnr)
    local self = setmetatable({
        bufnr = bufnr,
        -- Files at the base (merge base or reviewed version) and at HEAD.
        base = nil,
        head = nil,
        -- Base to HEAD, and where its deleted lines sit between HEAD's lines.
        committed = nil,
        committed_positions = nil,
        -- HEAD to itself, for when the buffer is as in HEAD.
        unchanged = nil,
        -- Set when new Files arrive, so the next update renders.
        files_changed = false,
        -- Base to the buffer, and HEAD to the buffer (uncommitted).
        from_base = nil,
        from_head = nil,
        -- The buffer's text, as last diffed.
        current = nil,
        -- Highlight group by changed line.
        changed_lines = {},
        -- Syntax state of each Text deleted lines come from.
        syntax_states = setmetatable({}, { __mode = "k" }),
        -- Content of each deleted-lines mark by id, and the style they were drawn with.
        deleted_marks = {},
        style_key = nil,
        -- Width of the number and sign columns.
        gutter_width = nil,
        -- What was last rendered.
        rendered_lines = nil,
        rendered_diff = nil,
        rendered_tick = nil,
    }, Buffer)
    attached[bufnr] = self
    for keymap, forward in pairs({ next_hunk = true, prev_hunk = false }) do
        if config.options.keymaps[keymap] then
            vim.keymap.set("n", config.options.keymaps[keymap], function()
                self:jump_to_hunk(forward)
            end, { buffer = bufnr })
        end
    end
    return self
end

function Buffer:detach()
    attached[self.bufnr] = nil
    if vim.api.nvim_buf_is_valid(self.bufnr) then
        for _, ns in ipairs({ Buffer.namespace, deleted_namespace }) do
            vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)
        end
        for _, lhs in ipairs({ config.options.keymaps.next_hunk, config.options.keymaps.prev_hunk }) do
            pcall(vim.keymap.del, "n", lhs, { buffer = self.bufnr })
        end
    end
end

-- New Files from git. Unchanged texts keep their diffs and highlights.
function Buffer:set_files(base, head)
    local unchanged = self.base and text_of(self.base).data == text_of(base).data and text_of(self.head).data == text_of(head).data
    if not unchanged then
        self.base, self.head = base, head
        -- Indexed once loaded, as deleted lines are read from them.
        text_of(base):index_lines()
        text_of(head):index_lines()
        self.committed = Diff.new(text_of(base), text_of(head))
        self.committed_positions = self.committed:deleted_positions()
        self.unchanged = Diff.unchanged(text_of(head))
        self.files_changed = true
    end
    self:update()
end

-- Diffs the buffer's lines and renders them.
function Buffer:update()
    local bufnr = self.bufnr
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    -- Already rendered as it is, like when attached again after HEAD moved without changing the file.
    if not self.files_changed and self.rendered_tick == vim.b[bufnr].changedtick then
        return self:restyle()
    end
    self.files_changed = false
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    -- As written to disk. An empty buffer still has one empty line.
    local empty = #lines == 1 and lines[1] == "" and vim.api.nvim_buf_call(bufnr, vim.fn.wordcount).bytes == 0
    local data = empty and "" or table.concat(lines, "\n") .. (vim.bo[bufnr].eol and "\n" or "")
    local base_text, head_text = text_of(self.base), text_of(self.head)
    if data == head_text.data then
        self.current = head_text
        self.from_base, self.from_head = self.committed, self.unchanged
    else
        self.current = Text.new(data)
        self.from_base = Diff.new(base_text, self.current)
        -- Without commits to the file everything is uncommitted.
        local no_commits = head_text.data == base_text.data
        self.from_head = no_commits and self.from_base or Diff.new(head_text, self.current)
    end
    -- Now, as TextChanged comes before the redraw.
    self:render()
    if self.rendered_lines then
        scroll.keep(bufnr, self.rendered_lines, lines)
    end
    self.rendered_lines, self.rendered_diff, self.rendered_tick = lines, self.from_base, vim.b[bufnr].changedtick
end

function Buffer:render()
    self:sign_added_lines()
    self:draw_deleted_lines()
    require("review.diagnostics").apply(self.bufnr)
end

-- Draws the deleted lines again when how they are drawn changed, like after a scroll, a resize or a new filetype.
function Buffer:restyle()
    if self:deleted_style().key ~= self.style_key then
        self:draw_deleted_lines()
        require("review.diagnostics").apply(self.bufnr)
    end
end

-- Redraws after a change without TextChanged, like an edit in another window.
function Buffer:refresh()
    if self.rendered_tick ~= vim.b[self.bufnr].changedtick then
        self:update()
    else
        self:restyle()
    end
end

-- Keeps marks already on the right lines.
function Buffer:sign_added_lines()
    local bufnr, existing = self.bufnr, {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, Buffer.namespace, 0, -1, { details = true })) do
        local mark_key = mark[2] .. " " .. mark[4].end_row .. " " .. mark[4].line_hl_group
        -- Edits can move marks onto the same lines.
        if existing[mark_key] then
            vim.api.nvim_buf_del_extmark(bufnr, Buffer.namespace, mark[1])
        else
            existing[mark_key] = mark[1]
        end
    end
    local changed_lines, run_start = {}, nil
    for line in self.from_base:each_added_line() do
        changed_lines[line] = "ReviewAdd"
    end
    for line in self.from_head:each_added_line() do
        changed_lines[line] = "ReviewLocalAdd"
    end
    for line = 1, vim.api.nvim_buf_line_count(bufnr) + 1 do
        if run_start and changed_lines[line] ~= changed_lines[run_start] then
            local mark_key = (run_start - 1) .. " " .. (line - 2) .. " " .. changed_lines[run_start]
            if existing[mark_key] then
                existing[mark_key] = nil
            else
                Buffer.sign(bufnr, run_start, line - 1, changed_lines[run_start] == "ReviewLocalAdd", "Add")
            end
            run_start = nil
        end
        run_start = run_start or changed_lines[line] and line
    end
    for _, id in pairs(existing) do
        vim.api.nvim_buf_del_extmark(bufnr, Buffer.namespace, id)
    end
    self.changed_lines = changed_lines
end

function Buffer:display_window()
    return vim.fn.win_findbuf(self.bufnr)[1] or vim.api.nvim_get_current_win()
end

function Buffer:gutter(uncommitted, kind)
    return gutter_chunks(self.gutter_width, uncommitted, kind)
end

-- Multi-line injected languages, like markdown code blocks: { first_row, last_row, lang }, inner ones last.
local function injected_blocks(bufnr, lang)
    local blocks = {}
    local function add(tree)
        for child_lang, child in pairs(tree:children()) do
            for _, region in ipairs(child:included_regions()) do
                local first, last = region[1], region[#region]
                -- A region ending at column 0 ends on the line before.
                local last_row = last and (last[5] == 0 and last[4] - 1 or last[4])
                if first and first[1] < last_row then
                    table.insert(blocks, { first[1], last_row, child_lang })
                end
            end
            add(child)
        end
    end
    local parser = lang and vim.treesitter.get_parser(bufnr, lang, { error = false })
    if parser then
        add(parser)
    end
    return blocks
end

-- How deleted lines are drawn. The key changes whenever any of it does.
function Buffer:deleted_style()
    local bufnr = self.bufnr
    local style = {
        leftcol = vim.fn.getwininfo(self:display_window())[1].leftcol,
        tabstop = vim.bo[bufnr].tabstop,
        lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype),
    }
    style.blocks = injected_blocks(bufnr, style.lang)
    local parts = { style.leftcol, style.tabstop, style.lang or "", self.gutter_width, vim.o.columns }
    for _, block in ipairs(style.blocks) do
        table.insert(parts, table.concat(block, ","))
    end
    style.key = table.concat(parts, " ")
    return style
end

-- The language of lines deleted above the row, and how many lines of it are above and below.
local function lang_at(row, style)
    local lang, lines_above, lines_below = style.lang, math.huge, math.huge
    for _, block in ipairs(style.blocks) do
        local first_row, last_row = block[1], block[2]
        if row - 1 >= first_row and row - 1 <= last_row or row >= first_row and row <= last_row then
            lang, lines_above, lines_below = block[3], math.max(row - first_row, 0), math.max(last_row - row + 1, 0)
        end
    end
    return lang, lines_above, lines_below
end

function Buffer:syntax_state(text)
    self.syntax_states[text] = self.syntax_states[text] or syntax.new_state()
    return self.syntax_states[text]
end

local function in_head_order(a, b)
    return a.position == b.position and a.index < b.index or a.position < b.position
end

-- Deleted lines by the row they are drawn at, in HEAD order: committed ones from the base, uncommitted ones from
-- HEAD. Marks which lines of each Text are shown deleted, to highlight nearby ones in one parse.
function Buffer:deleted_by_row()
    local by_row = {}
    for _, diff in ipairs({ self.from_base, self.from_head }) do
        self:syntax_state(diff.old_text).shown_deleted = {}
    end
    for uncommitted, diff in pairs({ [false] = self.from_base, [true] = self.from_head }) do
        local shown_deleted = self:syntax_state(diff.old_text).shown_deleted
        -- Without committed deletions, the base has none to show.
        local none = not uncommitted and next(self.committed_positions) == nil
        for old_line, index, row in diff:each_deleted_line() do
            local position = not none and (uncommitted and old_line or self.committed_positions[old_line])
            if position then
                shown_deleted[old_line] = true
                by_row[row] = by_row[row] or {}
                table.insert(by_row[row], {
                    old_line = old_line,
                    index = index,
                    position = position,
                    uncommitted = uncommitted,
                    text = diff.old_text,
                    line = diff.old_text:line(old_line),
                })
            end
        end
    end
    for _, deleted in pairs(by_row) do
        if #deleted > 1 then
            table.sort(deleted, in_head_order)
        end
    end
    return by_row
end

-- Reused for every mark, as most hold a line or two.
local content_parts = {}

-- What a deleted-lines mark shows, to tell whether an existing one still matches.
local function mark_content(deleted, above, lang)
    local count = 1
    content_parts[1] = (above and "^" or "v") .. (lang or "")
    for _, line in ipairs(deleted) do
        content_parts[count + 1] = line.uncommitted and "\n+" or "\n-"
        content_parts[count + 2] = line.line
        count = count + 2
    end
    return table.concat(content_parts, "", 1, count)
end

function Buffer:deleted_line_chunks(deleted, style, lang, lines_above, lines_below)
    local state = self:syntax_state(deleted.text)
    local highlights = lang and syntax.highlight(deleted.text, state, lang, deleted.old_line, lines_above, lines_below) or {}
    local chunks = deleted_text_chunks(deleted.line, highlights, deleted.uncommitted, style.leftcol, style.tabstop)
    return vim.list_extend(self:gutter(deleted.uncommitted, "Delete"), chunks)
end

-- Keeps marks already showing the right lines in the right place.
function Buffer:draw_deleted_lines()
    local bufnr = self.bufnr
    -- Measured before the redraw, a statuscolumn is too narrow.
    self.gutter_width = self.gutter_width or vim.fn.getwininfo(self:display_window())[1].textoff
    local style = self:deleted_style()
    if self.style_key ~= style.key then
        vim.api.nvim_buf_clear_namespace(bufnr, deleted_namespace, 0, -1)
        self.style_key, self.deleted_marks = style.key, {}
    end
    -- By row and content.
    local existing, drawn = {}, {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, deleted_namespace, 0, -1, {})) do
        existing[mark[2] .. self.deleted_marks[mark[1]]] = mark[1]
    end
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    for row, deleted in pairs(self:deleted_by_row()) do
        local above = row < line_count
        row = above and row or line_count - 1
        local lang, lines_above, lines_below
        if style.lang then
            lang, lines_above, lines_below = lang_at(row, style)
        end
        local content = mark_content(deleted, above, lang)
        local id = existing[row .. content]
        if not id or drawn[id] then
            id = vim.api.nvim_buf_set_extmark(bufnr, deleted_namespace, row, 0, {
                virt_lines = vim.tbl_map(function(line)
                    return self:deleted_line_chunks(line, style, lang, lines_above, lines_below)
                end, deleted),
                virt_lines_above = above,
                virt_lines_leftcol = true,
                -- Keeps lines inserted at the mark, like an undone delete, below the deleted lines.
                right_gravity = false,
            })
        end
        drawn[id] = content
    end
    for id in pairs(self.deleted_marks) do
        if not drawn[id] then
            vim.api.nvim_buf_del_extmark(bufnr, deleted_namespace, id)
        end
    end
    self.deleted_marks = drawn
end

function Buffer:jump_to_hunk(forward)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local target
    for _, hunk in ipairs(self.from_base.hunks) do
        local line = math.max(hunk.new_start, 1)
        if forward and line > cursor_line then
            target = target or line
        elseif not forward and line < cursor_line then
            target = line
        end
    end
    if target then
        vim.api.nvim_win_set_cursor(0, { target, 0 })
    end
end

return Buffer
