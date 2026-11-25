local config = require("review.config")
local git = require("review.git")
local scroll = require("review.scroll")
local session = require("review.session")

local M = {}

local namespace = vim.api.nvim_create_namespace("review")
local deleted_namespace = vim.api.nvim_create_namespace("review_deleted")
-- Committed and uncommitted.
local function sign_text(uncommitted)
    return config.options.signs[uncommitted and "uncommitted" or "committed"]
end

-- Attached buffers, with the file at the merge base and the current hunks against it.
local buffers = {}

-- Hunks from the file to the text, with the lines of the file they delete.
local function diff(from, to)
    local hunks = {}
    for _, hunk in ipairs(vim.text.diff(from.text, to, { result_type = "indices", indent_heuristic = true })) do
        local old, deleted, start, count = unpack(hunk)
        table.insert(hunks, { old = old, start = start, count = count, deleted = vim.list_slice(from.lines, old, old + deleted - 1) })
    end
    return hunks
end

-- The highlight groups of changed lines, kind being Add or Delete.
function M.sign(buf, first, last, uncommitted, kind)
    local group = "Review" .. (uncommitted and "Local" or "") .. kind
    vim.api.nvim_buf_set_extmark(buf, namespace, first - 1, 0, {
        end_row = last - 1,
        line_hl_group = group,
        number_hl_group = group .. "Nr",
        sign_text = sign_text(uncommitted),
        sign_hl_group = "ReviewSign" .. group:sub(7),
        priority = config.options.sign_priority,
    })
end

-- Lines of the file parsed around deleted lines at most, for highlights that depend on the code around them, like a
-- field holding a function.
local context = 30

-- Treesitter highlight of every byte of a line of the file, kept on the file. Parsed with up to context lines of the
-- file around it, or above and below when fewer, and the languages injected in them, but not the whole file, whose
-- tree takes a lot of memory. With the deleted lines near it not highlighted yet in the same parse, so a file with
-- many is parsed about once, and a hunk growing with every edit, like a held repeat key deleting lines, only
-- highlights its new lines.
local function highlight_line(file, lang, line, above, below)
    file.highlights[lang] = file.highlights[lang] or {}
    local cache = file.highlights[lang]
    if cache[line] then
        return cache[line]
    end
    local low, high = line, line
    -- Not past the lines of an injected language, like a code block.
    if above == math.huge and below == math.huge then
        local row = line - 1
        while row >= math.max(low - context, 1) do
            low = file.deleted[row] and not cache[row] and row or low
            row = row - 1
        end
        row = line + 1
        while row <= math.min(high + context, #file.lines) do
            high = file.deleted[row] and not cache[row] and row or high
            row = row + 1
        end
    end
    local top = math.max(low - math.min(above, context), 1)
    local bottom = math.min(high + math.min(below, context), #file.lines)
    -- The runs of deleted lines in between still to highlight, by their first and last row.
    local runs = {}
    for row = low, high do
        if row == line or file.deleted[row] and not cache[row] then
            cache[row] = {}
            local run = runs[#runs]
            if run and run[2] == row - 1 then
                run[2] = row
            else
                table.insert(runs, { row, row })
            end
        end
    end
    local source = table.concat(file.lines, "\n", top, bottom)
    local ok, parser = pcall(vim.treesitter.get_string_parser, source, lang)
    if not ok then
        return cache[line]
    end
    -- With the languages injected only in the deleted lines, as finding them in all the lines takes as long again.
    -- All at once, as parsing a range drops what was injected outside it.
    parser:parse(vim.tbl_map(function(run)
        return { run[1] - top, 0, run[2] - top + 1, 0 }
    end, runs))
    -- Injected languages after the ones they are in, so theirs win.
    local function add(tree)
        local tree_lang = tree:lang()
        local query = vim.treesitter.query.get(tree_lang, "highlights")
        for _, parsed in ipairs(query and tree:trees() or {}) do
            for _, run in ipairs(runs) do
                local from, to = run[1] - top, run[2] - top
                for id, node in query:iter_captures(parsed:root(), source, from, to + 1) do
                    local name = query.captures[id]
                    if not name:find("^_") and name ~= "spell" and name ~= "nospell" then
                        local start_row, start_col, end_row, end_col = node:range()
                        for row = math.max(start_row, from), math.min(end_row, to) do
                            local highlights = cache[top + row]
                            local columns = #file.lines[top + row]
                            for col = (row == start_row and start_col or 0) + 1, row == end_row and end_col or columns do
                                highlights[col] = "@" .. name .. "." .. tree_lang
                            end
                        end
                    end
                end
            end
        end
        for _, child in pairs(tree:children()) do
            add(child)
        end
    end
    add(parser)
    return cache[line]
end

-- Highlight ids by group name, which marks take faster than names, as they have every deleted line drawn again.
local hl_ids = setmetatable({}, {
    __index = function(ids, name)
        ids[name] = vim.api.nvim_get_hl_id_by_name(name)
        return ids[name]
    end,
})

-- Virtual text of a deleted line, scrolled by leftcol and padded to the edge like a line highlight.
local function deleted_chunks(text, highlights, uncommitted, leftcol, tabstop)
    local group = uncommitted and "ReviewLocalDelete" or "ReviewDelete"
    local base, background = hl_ids[group], hl_ids[group .. "Background"]
    local chunks, width, last = {}, 0, nil
    -- Neighbouring text with the same highlight goes in one chunk.
    local function add(shown, name)
        if chunks[1] and name == last then
            chunks[#chunks][1] = chunks[#chunks][1] .. shown
        else
            table.insert(chunks, { shown, name and { base, hl_ids[name], background } or base })
        end
        last = name
    end
    -- Where the run of shown characters with the same highlight started, added once it ends. By byte rather than
    -- with gmatch, which the JIT does not compile.
    local from, byte = nil, 1
    while byte <= #text do
        local name, code = highlights[byte], text:byte(byte)
        -- Past the UTF-8 continuation bytes of the character.
        local after = byte + 1
        while (text:byte(after) or 0) >= 128 and text:byte(after) < 192 do
            after = after + 1
        end
        -- Tabs to the next tabstop, and wide characters, like 日, two cells.
        local cells = code == 9 and tabstop - width % tabstop or code < 128 and 1 or vim.api.nvim_strwidth(text:sub(byte, after - 1))
        width = width + cells
        local shown = math.min(cells, width - leftcol)
        -- Shown as blanks, or < for a wide character cut by the edge of the window like Neovim does.
        local blank = shown > 0 and (code == 9 or shown < cells)
        if from and (blank or name ~= highlights[from]) then
            add(text:sub(from, byte - 1), highlights[from])
            from = nil
        end
        if blank then
            add(code == 9 and string.rep(" ", shown) or "<" .. string.rep(" ", shown - 1), name)
        elseif shown > 0 then
            from = from or byte
        end
        byte = after
    end
    if from then
        add(text:sub(from), highlights[from])
    end
    table.insert(chunks, { string.rep(" ", math.max(vim.o.columns - width + leftcol, 0)), base })
    return chunks
end

local function window(buf)
    return vim.fn.win_findbuf(buf)[1] or vim.api.nvim_get_current_win()
end

-- The number and sign columns of a changed line, for virtual lines, which have none.
function M.gutter(buf, uncommitted, kind)
    local text = sign_text(uncommitted)
    local sign = text .. string.rep(" ", buffers[buf].textoff - 1 - vim.fn.strdisplaywidth(text))
    return { { " ", hl_ids.LineNr }, { sign, hl_ids["ReviewSign" .. (uncommitted and "Local" or "") .. kind] } }
end

-- The first and last row and language of the languages injected over more than one line, like code blocks in
-- markdown, inner ones last. As parsed for the highlights of what was shown, as parsing all of them takes long.
local function blocks(buf, lang)
    local found = {}
    local function add(tree)
        for child_lang, child in pairs(tree:children()) do
            for _, region in ipairs(child:included_regions()) do
                local first, last = region[1], region[#region]
                -- Up to the start of the line after.
                local last_row = last and (last[5] == 0 and last[4] - 1 or last[4])
                if first and first[1] < last_row then
                    table.insert(found, { first[1], last_row, child_lang })
                end
            end
            add(child)
        end
    end
    local parser = lang and vim.treesitter.get_parser(buf, lang, { error = false })
    if parser then
        add(parser)
    end
    return found
end

-- How the deleted lines are drawn: scrolled, highlighted, in the gutter and padded to the edge.
local function style(buf)
    local leftcol, tabstop = vim.fn.getwininfo(window(buf))[1].leftcol, vim.bo[buf].tabstop
    local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
    local injected = blocks(buf, lang)
    local key = { leftcol, tabstop, lang or "", buffers[buf].textoff, vim.o.columns }
    for _, block in ipairs(injected) do
        table.insert(key, table.concat(block, ","))
    end
    return table.concat(key, " "), leftcol, tabstop, lang, injected
end

-- The language of the lines deleted above the row, like Lua in a code block of markdown, as they are parsed by
-- themselves, and how many lines of it are above and below them.
local function lang_at(row, lang, injected)
    local above, below = math.huge, math.huge
    for _, block in ipairs(injected) do
        if row - 1 >= block[1] and row - 1 <= block[2] or row >= block[1] and row <= block[2] then
            lang, above, below = block[3], math.max(row - block[1], 0), math.max(block[2] - row + 1, 0)
        end
    end
    return lang, above, below
end

-- What each mark of deleted lines shows, put together in the same table for all of them, as most are a line or two.
local shown_parts = {}

-- Drawn separately from the added lines, since they depend on the window's scroll and gutter. Marks already showing
-- the right lines in the right place are kept, so an edit only redraws the deleted lines it changed.
local function render_deleted(buf)
    local attached = buffers[buf]
    -- As last seen after a redraw. Right after an edit, before the redraw, a statuscolumn is not measured yet.
    attached.textoff = attached.textoff or vim.fn.getwininfo(window(buf))[1].textoff
    local drawn_as, leftcol, tabstop, lang, injected = style(buf)
    -- Every line is drawn again when how they are drawn changed.
    if attached.style ~= drawn_as then
        vim.api.nvim_buf_clear_namespace(buf, deleted_namespace, 0, -1)
        attached.style, attached.drawn = drawn_as, {}
    end
    local line_count = vim.api.nvim_buf_line_count(buf)
    -- The deleted lines by where they go, each with where it was in HEAD to order them by.
    local anchors = {}
    -- The lines of each file shown deleted, to highlight those near each other at once.
    attached.base.deleted, attached.head.deleted = {}, {}
    -- Deleted by commits against the base, and everything deleted against HEAD as uncommitted.
    for uncommitted, hunks in pairs({ [false] = attached.hunks, [true] = attached.local_hunks }) do
        for _, hunk in ipairs(hunks) do
            -- A pure deletion starts at the line before it, so goes above the line after it unless it is at the end.
            local row = hunk.count > 0 and hunk.start - 1 or hunk.start
            for i in ipairs(hunk.deleted) do
                local key = uncommitted and hunk.old + i - 1 or attached.committed_deletions[hunk.old + i - 1]
                if key then
                    (uncommitted and attached.head or attached.base).deleted[hunk.old + i - 1] = true
                    anchors[row] = anchors[row] or {}
                    table.insert(anchors[row], { key = key, order = i, hunk = hunk, uncommitted = uncommitted })
                end
            end
        end
    end
    -- The marks drawn before, by where they are now and what they show.
    local drawn, existing = {}, {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, deleted_namespace, 0, -1, {})) do
        existing[mark[2] .. attached.drawn[mark[1]]] = mark[1]
    end
    for row, lines in pairs(anchors) do
        table.sort(lines, function(a, b)
            return a.key == b.key and a.order < b.order or a.key < b.key
        end)
        local above = row < line_count
        row = above and row or line_count - 1
        local row_lang, lines_above, lines_below
        if lang then
            row_lang, lines_above, lines_below = lang_at(row, lang, injected)
        end
        -- Joined once, as adding to the string line by line copies it for every line of a large hunk.
        local count = 1
        shown_parts[1] = (above and "^" or "v") .. (row_lang or "")
        for _, line in ipairs(lines) do
            shown_parts[count + 1], shown_parts[count + 2] = line.uncommitted and "\n+" or "\n-", line.hunk.deleted[line.order]
            count = count + 2
        end
        local shown = table.concat(shown_parts, "", 1, count)
        local id = existing[row .. shown]
        if not id or drawn[id] then
            id = vim.api.nvim_buf_set_extmark(buf, deleted_namespace, row, 0, {
                virt_lines = vim.tbl_map(function(line)
                    local hunk = line.hunk
                    -- Committed deletions are lines of the base, the others of HEAD.
                    local file = line.uncommitted and attached.head or attached.base
                    local highlights = row_lang
                            and highlight_line(file, row_lang, hunk.old + line.order - 1, lines_above, lines_below)
                        or {}
                    local chunks = deleted_chunks(hunk.deleted[line.order], highlights, line.uncommitted, leftcol, tabstop)
                    return vim.list_extend(M.gutter(buf, line.uncommitted, "Delete"), chunks)
                end, lines),
                virt_lines_above = above,
                virt_lines_leftcol = true,
                -- Left gravity keeps lines inserted at the mark, like an undone delete, below the deleted lines.
                right_gravity = false,
            })
        end
        drawn[id] = shown
    end
    for id in pairs(attached.drawn) do
        if not drawn[id] then
            vim.api.nvim_buf_del_extmark(buf, deleted_namespace, id)
        end
    end
    attached.drawn = drawn
end

local function render(buf)
    -- Marks already over the right lines are kept, so an edit only signs again the lines it changed.
    local existing = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })) do
        local key = mark[2] .. " " .. mark[4].end_row .. " " .. mark[4].line_hl_group
        -- Edits can move marks onto the same lines, where one is enough.
        if existing[key] then
            vim.api.nvim_buf_del_extmark(buf, namespace, mark[1])
        else
            existing[key] = mark[1]
        end
    end
    -- The highlight of each added line, signed in runs of the same.
    local changed, first = {}, nil
    for i, hunks in ipairs({ buffers[buf].hunks, buffers[buf].local_hunks }) do
        for _, hunk in ipairs(hunks) do
            for line = hunk.start, hunk.start + hunk.count - 1 do
                changed[line] = i == 1 and "ReviewAdd" or "ReviewLocalAdd"
            end
        end
    end
    for line = 1, vim.api.nvim_buf_line_count(buf) + 1 do
        if first and changed[line] ~= changed[first] then
            local key = (first - 1) .. " " .. (line - 2) .. " " .. changed[first]
            if existing[key] then
                existing[key] = nil
            else
                M.sign(buf, first, line - 1, changed[first] == "ReviewLocalAdd", "Add")
            end
            first = nil
        end
        first = first or changed[line] and line
    end
    for _, id in pairs(existing) do
        vim.api.nvim_buf_del_extmark(buf, namespace, id)
    end
    buffers[buf].changed = changed
    render_deleted(buf)
    require("review.diagnostics").apply(buf)
end

-- Draws the deleted lines again once how they are drawn changed without an edit, like the window scrolled sideways,
-- the window changed width or the filetype changed.
local function restyle(buf)
    -- Edits without TextChanged, which only comes for the current buffer, like a language server's to a file in another
    -- window, are rendered first.
    if buffers[buf].tick ~= vim.b[buf].changedtick then
        M.update(buf)
    elseif style(buf) ~= buffers[buf].style then
        render_deleted(buf)
        require("review.diagnostics").apply(buf)
    end
end

local function jump(buf, forward)
    local current = vim.api.nvim_win_get_cursor(0)[1]
    local target
    for _, hunk in ipairs(buffers[buf] and buffers[buf].hunks or {}) do
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

-- Diffs the buffer against the merge base in memory, so edits show up while typing.
function M.update(buf)
    local attached = buffers[buf]
    if not attached or not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- Like the file is written, with the line break at the end unless it had none when read. Nothing for an empty
    -- buffer, which shows one empty line like a file of one does.
    local empty = #lines == 1 and lines[1] == "" and vim.api.nvim_buf_call(buf, vim.fn.wordcount).bytes == 0
    local text = empty and "" or table.concat(lines, "\n") .. (vim.bo[buf].eol and "\n" or "")
    local hunks = attached.committed
    if text == attached.head.text then
        -- As committed, which attach already diffed, like when the file was just opened.
        attached.hunks, attached.local_hunks = hunks, {}
    else
        hunks = diff(attached.base, text)
        -- Without commits to the file everything is uncommitted.
        attached.hunks = hunks
        attached.local_hunks = attached.head.text == attached.base.text and hunks or diff(attached.head, text)
    end
    -- Right away, as TextChanged comes before the redraw: scheduled, the edit would show without the deleted
    -- lines for a moment.
    render(buf)
    -- Not when attached, which is no edit.
    if attached.lines then
        scroll.keep(buf, attached.lines, lines)
    end
    attached.lines, attached.rendered, attached.tick = lines, hunks, vim.b[buf].changedtick
end

-- The gutter the deleted lines draw in is measured once a redraw drew it, as between an edit and the redraw a
-- statuscolumn measures narrower. Until a redraw shows it changed, the deleted lines keep the width last drawn.
local redrawn = {}
vim.api.nvim_set_decoration_provider(deleted_namespace, {
    on_win = function(_, win, buf)
        redrawn[win] = buffers[buf] and buf or nil
        return false
    end,
    on_end = function()
        for win, buf in pairs(redrawn) do
            local width = vim.fn.getwininfo(win)[1].textoff
            if win == window(buf) and width ~= buffers[buf].textoff then
                vim.schedule(function()
                    if buffers[buf] and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win) then
                        buffers[buf].textoff = width
                        restyle(buf)
                    end
                end)
            end
        end
        redrawn = {}
    end,
})

-- By window, the mark giving the number of its cursor line CursorLineNr on a changed line, whose number highlight
-- takes its place otherwise, and where it was put. In a namespace drawn only in that window, as the buffer can show
-- in others with their cursor elsewhere.
local cursor_marks = {}
-- Namespaces of closed windows, to use for new ones.
local spare_namespaces = {}

local function mark_cursor(win)
    local buf = vim.api.nvim_win_get_buf(win)
    local row = vim.api.nvim_win_get_cursor(win)[1] - 1
    local options, group = vim.wo[win].cursorlineopt, nil
    if vim.wo[win].cursorline and (options:find("number") or options:find("both")) then
        local sign = vim.api.nvim_buf_get_extmarks(buf, namespace, { row, 0 }, { row, 0 }, { details = true, overlap = true })[1]
        group = sign and sign[4].number_hl_group
    end
    local tick, mark = vim.b[buf].changedtick, cursor_marks[win]
    if mark and mark.buf == buf and mark.row == row and mark.group == group and mark.tick == tick then
        return
    end
    if mark and mark.id and vim.api.nvim_buf_is_valid(mark.buf) then
        vim.api.nvim_buf_del_extmark(mark.buf, mark.ns, mark.id)
    end
    local ns = mark and mark.ns
    if not ns then
        ns = table.remove(spare_namespaces) or vim.api.nvim_create_namespace("")
        vim.api.nvim__ns_set(ns, { wins = { win } })
    end
    cursor_marks[win] = {
        ns = ns,
        buf = buf,
        row = row,
        group = group,
        tick = tick,
        id = group and vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
            number_hl_group = group:gsub("Nr$", "CursorNr"),
            priority = config.options.sign_priority + 1,
        }),
    }
end

-- Once the screen shows the rendered hunks, so cursor moves and scrolls are kept by the next render. The gutter
-- and how the deleted lines are drawn can also have changed without an edit.
function M.settled()
    for win, mark in pairs(cursor_marks) do
        if not vim.api.nvim_win_is_valid(win) then
            if vim.api.nvim_buf_is_valid(mark.buf) then
                vim.api.nvim_buf_clear_namespace(mark.buf, mark.ns, 0, -1)
            end
            table.insert(spare_namespaces, mark.ns)
            cursor_marks[win] = nil
        end
    end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        mark_cursor(win)
        local buf = vim.api.nvim_win_get_buf(win)
        if buffers[buf] and buffers[buf].rendered == buffers[buf].hunks then
            restyle(buf)
            scroll.settle(win, buffers[buf].lines)
        end
    end
end

-- Buffers of files, also ones that do not exist, to show a deleted file as all deleted lines.
local function attachable(buf)
    local file = vim.api.nvim_buf_get_name(buf)
    return vim.bo[buf].buftype == "" and file ~= "" and vim.fn.isdirectory(file) == 0
end

-- With the file in HEAD and at the merge base when already read.
function M.attach(buf, shown)
    if not attachable(buf) then
        return
    end
    -- No base when the file was added since the merge base, no head when it was added since HEAD.
    local head, base
    if shown then
        head, base = shown[1], shown[2]
    else
        head, base = git.show(vim.api.nvim_buf_get_name(buf), "HEAD", session.merge_base)
    end
    -- Untracked, outside the repo or binary.
    if not (base or head) or ((base or "") .. (head or "")):find("\0", 1, true) then
        return M.detach(buf)
    end
    if not buffers[buf] then
        buffers[buf] = { hunks = {}, drawn = {} }
        for key, forward in pairs({ next_hunk = true, prev_hunk = false }) do
            if config.options.keymaps[key] then
                vim.keymap.set("n", config.options.keymaps[key], function()
                    jump(buf, forward)
                end, { buffer = buf })
            end
        end
    end
    local attached = buffers[buf]
    -- With the treesitter highlights of their lines by language, for the deleted lines.
    attached.base = { text = base or "", lines = vim.split(base or "", "\n"), highlights = {} }
    attached.head = { text = head or "", lines = vim.split(head or "", "\n"), highlights = {} }
    -- Lines of the base deleted by commits, other deleted lines are only deleted locally. With where they were
    -- between the lines of HEAD: after the line before them, or before the lines that replaced them.
    attached.committed_deletions = {}
    attached.committed = diff(attached.base, attached.head.text)
    for _, hunk in ipairs(attached.committed) do
        for i = 1, #hunk.deleted do
            attached.committed_deletions[hunk.old + i - 1] = hunk.count == 0 and hunk.start + 0.5 or hunk.start - 0.5
        end
    end
    M.update(buf)
end

-- Read by one git process, as a process for each adds up with many buffers open.
function M.attach_all()
    local bufs = vim.tbl_filter(function(buf)
        return vim.api.nvim_buf_is_loaded(buf) and attachable(buf)
    end, vim.api.nvim_list_bufs())
    local shown = git.show_each(vim.tbl_map(vim.api.nvim_buf_get_name, bufs), { "HEAD", session.merge_base })
    for i, buf in ipairs(bufs) do
        M.attach(buf, shown[i])
    end
end

function M.detach(buf)
    if not buffers[buf] then
        return
    end
    buffers[buf] = nil
    if vim.api.nvim_buf_is_valid(buf) then
        for _, ns in ipairs({ namespace, deleted_namespace }) do
            vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        end
        for _, mark in pairs(cursor_marks) do
            vim.api.nvim_buf_clear_namespace(buf, mark.ns, 0, -1)
        end
        for _, key in ipairs({ config.options.keymaps.next_hunk, config.options.keymaps.prev_hunk }) do
            pcall(vim.keymap.del, "n", key, { buffer = buf })
        end
    end
end

function M.detach_all()
    for buf in pairs(buffers) do
        M.detach(buf)
    end
end

-- Right away, as by the time the screen settled it would have shown the deleted lines unscrolled.
function M.scrolled()
    for win in pairs(vim.v.event) do
        local id = tonumber(win)
        if id and vim.api.nvim_win_is_valid(id) and buffers[vim.api.nvim_win_get_buf(id)] then
            restyle(vim.api.nvim_win_get_buf(id))
        end
    end
end

-- Shows the deleted lines above the first line when the buffer is opened at the top, like for a deleted file.
function M.reveal(buf)
    if buffers[buf] then
        scroll.reveal(buf)
    end
end

-- The highlight of each changed line, as last rendered.
function M.changed(buf)
    return buffers[buf] and buffers[buf].changed or {}
end

function M.first_hunk(buf)
    return buffers[buf] and buffers[buf].hunks[1]
end

return M
