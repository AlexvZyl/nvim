-- Buffer is an attached buffer of a reviewed file: its diffs against HEAD and the base, and the marks drawing them.
local config = require("review.config")
local cursor = require("review.cursor")
local draw = require("review.draw")
local scroll = require("review.scroll")
local Text = require("review.text")

local Buffer = {}
Buffer.__index = Buffer

local deleted_namespace = vim.api.nvim_create_namespace("review_deleted")

-- By buffer number.
local attached = {}

function Buffer.get(buf)
    return attached[buf]
end

function Buffer.each()
    return pairs(attached)
end

function Buffer.new(buf)
    local self = setmetatable({
        buf = buf,
        -- The file at the base (merge base or reviewed version) and at HEAD.
        base_text = nil,
        head_text = nil,
        -- Base to HEAD.
        committed_hunks = nil,
        -- Where each base line deleted by a commit sits between HEAD's lines.
        committed_deleted_at = nil,
        -- Base to buffer, and HEAD to buffer (uncommitted).
        hunks_from_base = {},
        hunks_from_head = {},
        -- Highlight group by changed line.
        changed_lines = {},
        -- Content of each deleted-lines mark by id, and the style they were drawn with.
        deleted_marks = {},
        deleted_style_key = nil,
        -- Width of the number and sign columns.
        gutter_width = nil,
        -- What was last rendered.
        rendered_lines = nil,
        rendered_hunks = nil,
        rendered_tick = nil,
    }, Buffer)
    attached[buf] = self
    for keymap, forward in pairs({ next_hunk = true, prev_hunk = false }) do
        if config.options.keymaps[keymap] then
            vim.keymap.set("n", config.options.keymaps[keymap], function()
                self:jump_to_hunk(forward)
            end, { buffer = buf })
        end
    end
    return self
end

function Buffer:detach()
    attached[self.buf] = nil
    if vim.api.nvim_buf_is_valid(self.buf) then
        for _, ns in ipairs({ draw.namespace, deleted_namespace }) do
            vim.api.nvim_buf_clear_namespace(self.buf, ns, 0, -1)
        end
        cursor.clear(self.buf)
        for _, lhs in ipairs({ config.options.keymaps.next_hunk, config.options.keymaps.prev_hunk }) do
            pcall(vim.keymap.del, "n", lhs, { buffer = self.buf })
        end
    end
end

-- Nil content means the file does not exist there. Unchanged content keeps its diffs and highlights.
function Buffer:set_texts(head_content, base_content)
    local unchanged = self.base_text
        and self.base_text.content == (base_content or "")
        and self.head_text.content == (head_content or "")
    if not unchanged then
        self.base_text, self.head_text = Text.new(base_content), Text.new(head_content)
        self.committed_hunks = self.base_text:diff(self.head_text.content)
        -- After the line before them, or before the lines replacing them.
        self.committed_deleted_at = {}
        for _, hunk in ipairs(self.committed_hunks) do
            for i = 1, #hunk.deleted_lines do
                local position = hunk.new_count == 0 and hunk.new_start + 0.5 or hunk.new_start - 0.5
                self.committed_deleted_at[hunk.old_start + i - 1] = position
            end
        end
    end
    self:update()
end

-- Diffs the buffer's lines and renders them.
function Buffer:update()
    local buf = self.buf
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- As written to disk. An empty buffer still has one empty line.
    local empty = #lines == 1 and lines[1] == "" and vim.api.nvim_buf_call(buf, vim.fn.wordcount).bytes == 0
    local content = empty and "" or table.concat(lines, "\n") .. (vim.bo[buf].eol and "\n" or "")
    if content == self.head_text.content then
        self.hunks_from_base, self.hunks_from_head = self.committed_hunks, {}
    else
        self.hunks_from_base = self.base_text:diff(content)
        -- Without commits to the file everything is uncommitted.
        local no_commits = self.head_text.content == self.base_text.content
        self.hunks_from_head = no_commits and self.hunks_from_base or self.head_text:diff(content)
    end
    -- Now, as TextChanged comes before the redraw.
    self:render()
    if self.rendered_lines then
        scroll.keep(buf, self.rendered_lines, lines)
    end
    self.rendered_lines, self.rendered_hunks, self.rendered_tick = lines, self.hunks_from_base, vim.b[buf].changedtick
end

function Buffer:render()
    self:sign_added_lines()
    self:draw_deleted_lines()
    require("review.diagnostics").apply(self.buf)
end

-- Redraws after a change without TextChanged: an edit in another window, a scroll, a resize or a new filetype.
function Buffer:refresh()
    if self.rendered_tick ~= vim.b[self.buf].changedtick then
        self:update()
    elseif self:deleted_style().key ~= self.deleted_style_key then
        self:draw_deleted_lines()
        require("review.diagnostics").apply(self.buf)
    end
end

-- Keeps marks already on the right lines.
function Buffer:sign_added_lines()
    local buf, existing = self.buf, {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, draw.namespace, 0, -1, { details = true })) do
        local mark_key = mark[2] .. " " .. mark[4].end_row .. " " .. mark[4].line_hl_group
        -- Edits can move marks onto the same lines.
        if existing[mark_key] then
            vim.api.nvim_buf_del_extmark(buf, draw.namespace, mark[1])
        else
            existing[mark_key] = mark[1]
        end
    end
    local changed_lines, run_start = {}, nil
    for i, hunks in ipairs({ self.hunks_from_base, self.hunks_from_head }) do
        for _, hunk in ipairs(hunks) do
            for line = hunk.new_start, hunk.new_start + hunk.new_count - 1 do
                changed_lines[line] = i == 1 and "ReviewAdd" or "ReviewLocalAdd"
            end
        end
    end
    for line = 1, vim.api.nvim_buf_line_count(buf) + 1 do
        if run_start and changed_lines[line] ~= changed_lines[run_start] then
            local mark_key = (run_start - 1) .. " " .. (line - 2) .. " " .. changed_lines[run_start]
            if existing[mark_key] then
                existing[mark_key] = nil
            else
                draw.sign(buf, run_start, line - 1, changed_lines[run_start] == "ReviewLocalAdd", "Add")
            end
            run_start = nil
        end
        run_start = run_start or changed_lines[line] and line
    end
    for _, id in pairs(existing) do
        vim.api.nvim_buf_del_extmark(buf, draw.namespace, id)
    end
    self.changed_lines = changed_lines
end

function Buffer:display_window()
    return vim.fn.win_findbuf(self.buf)[1] or vim.api.nvim_get_current_win()
end

function Buffer:gutter(uncommitted, kind)
    return draw.gutter(self.gutter_width, uncommitted, kind)
end

-- Multi-line injected languages, like markdown code blocks: { first_row, last_row, lang }, inner ones last.
local function injected_blocks(buf, lang)
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
    local parser = lang and vim.treesitter.get_parser(buf, lang, { error = false })
    if parser then
        add(parser)
    end
    return blocks
end

-- How deleted lines are drawn. The key changes whenever any of it does.
function Buffer:deleted_style()
    local buf = self.buf
    local style = {
        leftcol = vim.fn.getwininfo(self:display_window())[1].leftcol,
        tabstop = vim.bo[buf].tabstop,
        lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype),
    }
    style.blocks = injected_blocks(buf, style.lang)
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

-- Deleted lines by the row they are drawn at, in HEAD order. Marks which lines of each text are shown deleted.
function Buffer:deleted_by_row()
    local by_row = {}
    self.base_text.shown_deleted, self.head_text.shown_deleted = {}, {}
    for uncommitted, hunks in pairs({ [false] = self.hunks_from_base, [true] = self.hunks_from_head }) do
        for _, hunk in ipairs(hunks) do
            -- A pure deletion goes above the line after it.
            local row = hunk.new_count > 0 and hunk.new_start - 1 or hunk.new_start
            for index in ipairs(hunk.deleted_lines) do
                local old_line = hunk.old_start + index - 1
                local position = uncommitted and old_line or self.committed_deleted_at[old_line]
                if position then
                    (uncommitted and self.head_text or self.base_text).shown_deleted[old_line] = true
                    by_row[row] = by_row[row] or {}
                    table.insert(by_row[row], { position = position, index = index, hunk = hunk, uncommitted = uncommitted })
                end
            end
        end
    end
    for _, deleted in pairs(by_row) do
        table.sort(deleted, function(a, b)
            return a.position == b.position and a.index < b.index or a.position < b.position
        end)
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
        content_parts[count + 2] = line.hunk.deleted_lines[line.index]
        count = count + 2
    end
    return table.concat(content_parts, "", 1, count)
end

function Buffer:deleted_line_chunks(line, style, lang, lines_above, lines_below)
    local hunk = line.hunk
    -- Committed deletions are lines of the base, the others of HEAD.
    local text = line.uncommitted and self.head_text or self.base_text
    local highlights = lang and text:highlight(lang, hunk.old_start + line.index - 1, lines_above, lines_below) or {}
    local chunks = draw.deleted_line(hunk.deleted_lines[line.index], highlights, line.uncommitted, style.leftcol, style.tabstop)
    return vim.list_extend(self:gutter(line.uncommitted, "Delete"), chunks)
end

-- Keeps marks already showing the right lines in the right place.
function Buffer:draw_deleted_lines()
    local buf = self.buf
    -- Measured before the redraw, a statuscolumn is too narrow.
    self.gutter_width = self.gutter_width or vim.fn.getwininfo(self:display_window())[1].textoff
    local style = self:deleted_style()
    if self.deleted_style_key ~= style.key then
        vim.api.nvim_buf_clear_namespace(buf, deleted_namespace, 0, -1)
        self.deleted_style_key, self.deleted_marks = style.key, {}
    end
    -- By row and content.
    local existing, drawn = {}, {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, deleted_namespace, 0, -1, {})) do
        existing[mark[2] .. self.deleted_marks[mark[1]]] = mark[1]
    end
    local line_count = vim.api.nvim_buf_line_count(buf)
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
            id = vim.api.nvim_buf_set_extmark(buf, deleted_namespace, row, 0, {
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
            vim.api.nvim_buf_del_extmark(buf, deleted_namespace, id)
        end
    end
    self.deleted_marks = drawn
end

function Buffer:jump_to_hunk(forward)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local target
    for _, hunk in ipairs(self.hunks_from_base) do
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
