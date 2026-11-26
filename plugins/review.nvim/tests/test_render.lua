local h = require("tests.helpers")

local T = {}

-- Committed: line 10 modified. Uncommitted: line 5 modified, line 7 deleted and the committed line 10 deleted.
local function setup()
    local committed = h.edit(h.lines(12), { [10] = "mod 10" })
    h.repo(h.lines(12), committed, h.edit(committed, { [5] = "local 5", [7] = false, [10] = false }))
    return h.open()
end

-- The mark of the namespace starting on the line.
local function find(buf, namespace, line)
    return h.marks(buf, namespace, line, line)[1]
end

function T.committed_lines_have_a_solid_sign_and_background()
    h.repo(h.lines(12), h.edit(h.lines(12), { [10] = "mod 10" }))
    local buf = h.open()
    local mark = find(buf, "review", 10)
    assert(mark, "no mark on the committed line")
    assert(mark[4].sign_text == "│ ", vim.inspect(mark[4].sign_text))
    assert(mark[4].line_hl_group == "ReviewAdd" and mark[4].priority == 6, vim.inspect(mark[4]))
    local deleted = h.virt_lines(find(buf, "review_deleted", 10))
    assert(#deleted == 1 and deleted[1].text == "line 10" and deleted[1].sign == "│", vim.inspect(deleted))
    assert(deleted[1].group == "ReviewSignDelete")
end

function T.uncommitted_lines_have_a_dashed_sign()
    local buf = setup()
    local mark = find(buf, "review", 5)
    assert(mark, "no mark on the uncommitted line")
    assert(mark[4].sign_text == "╎ ", vim.inspect(mark[4].sign_text))
    assert(mark[4].sign_hl_group == "ReviewSignLocalAdd")
    assert(mark[4].line_hl_group == "ReviewLocalAdd")
end

function T.uncommitted_deletions_are_shown_with_a_dashed_sign()
    local buf = setup()
    local deleted = {}
    for _, mark in ipairs(h.marks(buf, "review_deleted", 1, 12)) do
        vim.list_extend(deleted, h.virt_lines(mark))
    end
    local by_text = {}
    for _, line in ipairs(deleted) do
        by_text[line.text] = line
    end
    assert(by_text["line 5"] and by_text["line 5"].group == "ReviewSignLocalDelete", vim.inspect(deleted))
    assert(by_text["line 7"] and by_text["line 7"].sign == "╎", vim.inspect(deleted))
    -- Deleting a line added by a commit shows it as deleted locally, under the line it replaced.
    assert(by_text["mod 10"] and by_text["mod 10"].group == "ReviewSignLocalDelete", vim.inspect(deleted))
    assert(by_text["line 10"] and by_text["line 10"].group == "ReviewSignDelete", vim.inspect(deleted))
end

-- The text of all deleted lines from the top, in the order they show.
local function deleted_texts(buf)
    local texts = {}
    for _, mark in ipairs(h.marks(buf, "review_deleted", 1, vim.api.nvim_buf_line_count(buf))) do
        for _, line in ipairs(h.virt_lines(mark)) do
            table.insert(texts, line.text)
        end
    end
    return texts
end

-- Saving reads the file from git again, which keeps what it worked out before when that did not change.
function T.saving_keeps_the_deleted_lines()
    h.repo(h.lines(12), h.edit(h.lines(12), { [10] = false }))
    h.review("file.txt")
    local buf = vim.api.nvim_get_current_buf()
    h.keys("5Gdd")
    vim.cmd("silent write")
    local texts, signs = deleted_texts(buf), {}
    for _, mark in ipairs(h.marks(buf, "review_deleted", 1, vim.api.nvim_buf_line_count(buf))) do
        for _, line in ipairs(h.virt_lines(mark)) do
            table.insert(signs, line.sign)
        end
    end
    require("review").stop()
    assert(vim.deep_equal(texts, { "line 5", "line 10" }), vim.inspect(texts))
    assert(vim.deep_equal(signs, { "╎", "│" }), vim.inspect(signs))
end

-- Deleted lines show in the order they were in, wherever they were deleted.
local function shows_in_order(committed, working, texts)
    committed = h.edit(h.lines(12), committed)
    h.repo(h.lines(12), committed, h.edit(committed, working))
    local shown = deleted_texts(h.open())
    assert(vim.deep_equal(shown, texts), vim.inspect(shown))
end

function T.deleted_lines_show_in_order_when_deleted_before_committed_deletions()
    shows_in_order({ [6] = false, [7] = false }, { [5] = false }, { "line 5", "line 6", "line 7" })
end

function T.deleted_lines_show_in_order_when_deleted_after_committed_deletions()
    shows_in_order({ [6] = false }, { [6] = false }, { "line 6", "line 7" })
end

function T.deleted_lines_show_in_order_when_a_committed_change_is_deleted()
    shows_in_order({ [6] = "mod 6" }, { [6] = false }, { "line 6", "mod 6" })
end

function T.deleting_everything_renders()
    h.repo(h.lines(3), h.lines(3), {})
    local buf = h.open()
    local marks = h.marks(buf, "review_deleted", 1, 1)
    assert(#marks == 1 and #h.virt_lines(marks[1]) == 3, vim.inspect(marks))
end

function T.deletion_at_the_end_goes_below_the_last_line()
    h.repo(h.lines(5), h.lines(4))
    local buf = h.open()
    local mark = h.marks(buf, "review_deleted", 1, 5)[1]
    assert(mark and mark[2] == 3 and not mark[4].virt_lines_above, vim.inspect(mark))
end

-- Tabs go to the next tabstop and the text scrolls with the window, a cell at a time.
function T.deleted_lines_expand_tabs_and_scroll()
    h.repo({ "\tcafé x\t日y", "keep" }, { "keep" })
    local buf = h.open()
    vim.bo[buf].tabstop, vim.wo.wrap = 4, false
    local width
    local function text(leftcol)
        vim.fn.winrestview({ leftcol = leftcol })
        require("review.render").update(buf)
        local chunks = h.marks(buf, "review_deleted", 1, 1)[1][4].virt_lines[1]
        local texts = vim.tbl_map(function(chunk)
            return chunk[1]
        end, chunks)
        -- Padded to the edge of the window however far it is scrolled.
        width = math.min(width or math.huge, vim.fn.strdisplaywidth(table.concat(texts)))
        return table.concat(texts, "", 3, #texts - 1)
    end
    -- Past the é, which is two bytes and one cell, and through the 日, which is two cells and cut shows as <.
    local shown = { text(0), text(2), text(5), text(8), text(13) }
    vim.wo.wrap = true
    assert(vim.deep_equal(shown, { "    café x  日y", "  café x  日y", "afé x  日y", " x  日y", "<y" }), vim.inspect(shown))
    assert(width >= vim.o.columns, width)
end

-- Deleting a line in the middle of a run of changed lines leaves the line after it, which is not changed, unsigned.
function T.deleting_in_a_changed_run_shortens_it()
    h.repo(h.lines(20), h.edit(h.lines(20), { [10] = "mod 10", [11] = "mod 11" }))
    local buf = h.open()
    h.keys("11Gdd")
    local covering = vim.tbl_filter(function(mark)
        return mark[2] <= 10 and mark[4].end_row >= 10
    end, vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace("review"), 0, -1, { details = true }))
    assert(#covering == 0, vim.inspect(covering))
end

-- Deleting the lines from one changed line to the line before the next moves both their marks onto that line.
function T.changed_lines_moved_onto_one_line_keep_one_sign()
    h.repo(h.lines(20), h.edit(h.lines(20), { [3] = "mod 3", [5] = "mod 5" }))
    local buf = h.open()
    h.keys("3G2dd")
    local marks = h.marks(buf, "review", 3, 3)
    assert(#marks == 1, vim.inspect(marks))
end

-- Like a language server editing a file shown in another window, which gets no TextChanged.
function T.edits_without_text_changed_render_once_settled()
    h.repo(h.lines(5), h.lines(5))
    local buf = h.open()
    local render = require("review.render")
    h.keys("ggdG")
    vim.api.nvim_buf_set_lines(buf, 1, 1, false, { "added" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    render.settled()
    local changed = render.changed(buf)[2]
    vim.api.nvim_buf_set_lines(buf, 1, 2, false, {})
    local ok, err = pcall(render.update, buf)
    assert(changed == "ReviewLocalAdd", vim.inspect(render.changed(buf)))
    assert(ok, err)
end

-- Unloaded, like with :bdelete, it has no lines to draw on until it is read again.
function T.an_unloaded_file_is_not_drawn()
    h.repo(h.lines(12), h.edit(h.lines(12), { [3] = false }))
    h.review("file.txt")
    local buf = vim.api.nvim_get_current_buf()
    -- The gutter widening redraws the deleted lines once the screen is drawn.
    vim.wo.number = not vim.wo.number
    vim.cmd("redraw")
    vim.cmd("enew")
    vim.cmd.bunload(buf)
    vim.v.errmsg = ""
    h.flush()
    local message = vim.v.errmsg
    vim.cmd.edit("file.txt")
    local marks = h.marks(buf, "review_deleted", 1, 12)
    vim.wo.number = not vim.wo.number
    h.start()
    assert(message == "", message)
    assert(#marks == 1, vim.inspect(marks))
end

-- With the cursor on a line added past the end of the file, which reloading it takes away.
function T.reloading_drops_the_line_the_cursor_was_on()
    h.repo(h.lines(10), h.lines(10))
    h.review("file.txt")
    h.keys("Goadded\27")
    vim.cmd("edit!")
    vim.v.errmsg = ""
    local ok, err = pcall(require("review.render").settled)
    h.flush()
    local active = require("review").active()
    h.start()
    assert(ok, err)
    assert(active and vim.v.errmsg == "", vim.v.errmsg)
end

-- Typing while it is open only gives TextChangedP.
function T.typing_with_the_completion_menu_open_renders()
    h.repo({ "line", "lin" }, { "line", "lin" })
    h.review("file.txt")
    local buf = vim.api.nvim_get_current_buf()
    local completeopt = vim.o.completeopt
    vim.o.completeopt = "menu,menuone,noinsert"
    h.input("2GA<C-n>")
    h.input("e")
    local open, changed = vim.fn.pumvisible(), require("review.render").changed(buf)[2]
    h.input("<C-e><Esc>")
    vim.o.completeopt = completeopt
    assert(open == 1, "the menu closed")
    assert(changed == "ReviewLocalAdd", vim.inspect(require("review.render").changed(buf)))
end

function T.stopping_clears_the_buffers()
    setup()
    local buf = vim.api.nvim_get_current_buf()
    require("review").stop()
    local left = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, {})
    assert(#left == 0, vim.inspect(left))
end

-- Without a line break at the end the last line is not changed.
function T.a_file_without_a_line_break_at_the_end_is_unchanged()
    h.repo({ "a", "b" }, { "a", "b" })
    h.commit({ ["file.txt"] = "a\nb\nc" })
    local buf = h.open()
    local mark = h.marks(buf, "review", 3, 3)[1]
    assert(mark and mark[4].sign_text == "│ ", vim.inspect(mark))
    assert(#h.marks(buf, "review_deleted", 1, 3) == 0, vim.inspect(h.marks(buf, "review_deleted", 1, 3)))
end

-- Its buffer has the same one empty line as an empty file's.
function T.a_file_of_one_empty_line_is_unchanged()
    h.repo({ "" }, { "" })
    local buf = h.open()
    assert(#h.marks(buf, "review_deleted", 1, 1) == 0, vim.inspect(h.marks(buf, "review_deleted", 1, 1)))
end

-- TextChanged comes before the redraw, rendered later the edit flashes without the deleted lines.
function T.deleted_lines_render_before_the_redraw()
    h.repo(h.lines(12), h.lines(12))
    local buf = h.open()
    vim.cmd("normal! 5Gdd")
    require("review.render").update(buf)
    local deleted = h.virt_lines(h.marks(buf, "review_deleted", 1, 12)[1] or { 0, 0, 0, {} })
    assert(#deleted == 1 and deleted[1].text == "line 5", vim.inspect(deleted))
end

function T.lines_deleted_at_the_top_show_when_opened()
    h.repo(h.lines(12), vim.list_slice(h.lines(12), 3))
    h.review("file.txt")
    local topfill = vim.fn.winsaveview().topfill
    require("review").stop()
    assert(topfill == 2, topfill)
end

-- The panel puts the first hunk in the middle of the window, which hides what is above the first line again.
function T.lines_deleted_at_the_top_show_when_opened_from_the_panel()
    h.repo(h.lines(12), vim.list_slice(h.lines(12), 3))
    local main = h.review()
    h.pick("file.txt")
    local topfill = vim.api.nvim_win_call(main, vim.fn.winsaveview).topfill
    require("review").stop()
    assert(topfill == 2, topfill)
end

-- Width of the number and sign columns of the window.
local function textoff()
    return vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff
end

-- Width of the number and sign columns drawn in the first of the deleted lines.
local function gutter(buf)
    local chunks = h.marks(buf, "review_deleted", 1, 20)[1][4].virt_lines[1]
    return vim.fn.strdisplaywidth(chunks[1][1] .. chunks[2][1])
end

-- A statuscolumn with relative numbers measures narrower right after an edit, until the redraw.
function T.deleted_lines_keep_the_gutter_width_while_editing()
    h.repo(h.lines(20), h.lines(20))
    local buf = h.open()
    vim.wo.number, vim.wo.relativenumber = true, true
    vim.wo.statuscolumn = "%#LineNr# %*%s%=%{v:relnum?v:relnum:v:lnum}%*  "
    vim.cmd("redraw")
    h.keys("5Gdd")
    h.keys("u")
    local width = textoff()
    vim.cmd("normal! 5Gdd")
    require("review.render").update(buf)
    local drawn = gutter(buf)
    vim.wo.number, vim.wo.relativenumber, vim.wo.statuscolumn = false, false, ""
    assert(drawn == width, ("gutter %d, window %d"):format(drawn, width))
end

function T.deleted_lines_follow_the_gutter_when_numbers_are_shown()
    h.repo(h.lines(20), h.lines(20))
    local buf = h.open()
    h.keys("5Gdd")
    vim.wo.number = true
    h.flush()
    local width = textoff()
    local drawn = gutter(buf)
    vim.wo.number = false
    assert(drawn == width, ("gutter %d, window %d"):format(drawn, width))
end

function T.deleted_lines_are_padded_to_the_edge_after_a_resize()
    h.repo(h.lines(5), h.lines(4))
    local buf = h.open()
    vim.o.columns = 260
    vim.cmd("redraw")
    require("review.render").settled()
    local chunks = h.marks(buf, "review_deleted", 1, 5)[1][4].virt_lines[1]
    local width = vim.fn.strdisplaywidth(table.concat(vim.tbl_map(function(chunk)
        return chunk[1]
    end, chunks)))
    vim.o.columns = 200
    assert(width >= 260, width)
end

-- Like markdown code blocks in some colorschemes.
function T.deleted_lines_keep_their_background_over_syntax_with_its_own()
    local keyword = vim.api.nvim_get_hl(0, { name = "@keyword.lua" })
    vim.api.nvim_set_hl(0, "@keyword.lua", { fg = "#ff0000", bg = "#00ff00" })
    h.repo({ "local x = 1", "keep" }, { "keep" })
    local buf = h.open()
    vim.bo[buf].filetype = "lua"
    require("review.render").settled()
    local chunks = h.marks(buf, "review_deleted", 1, 1)[1][4].virt_lines[1]
    vim.api.nvim_set_hl(0, "@keyword.lua", keyword)
    vim.bo[buf].filetype = ""
    local groups = vim.iter(chunks):find(function(chunk)
        return type(chunk[2]) == "table" and chunk[2][2]:match("^@keyword")
    end)[2]
    local background = vim.api.nvim_get_hl(0, { name = groups[3] or "", link = false }).bg
    local delete = vim.api.nvim_get_hl(0, { name = "ReviewDelete", link = false }).bg
    assert(groups[#groups] ~= "@keyword.lua" and background == delete, vim.inspect({ groups, background, delete }))
end

function T.deleted_lines_are_highlighted_in_the_language_they_are_in()
    local block = { "# t", "", "```lua", "local x = {", "    y = 1,", "}", "```" }
    h.repo(block, h.edit(block, { [5] = false }))
    local buf = h.open()
    vim.bo[buf].filetype = "markdown"
    -- Which parses what is shown.
    vim.cmd.redraw()
    require("review.render").settled()
    local chunks = h.marks(buf, "review_deleted", 1, #block)[1][4].virt_lines[1]
    vim.bo[buf].filetype = ""
    assert(vim.iter(chunks):any(function(chunk)
        return type(chunk[2]) == "table" and chunk[2][2]:match("%.lua$")
    end), vim.inspect(chunks))
end

-- The highlight of the chunk of a deleted line showing text.
local function deleted_highlight(buf, text, line_count)
    local chunks = h.marks(buf, "review_deleted", 1, line_count)[1][4].virt_lines[1]
    for _, chunk in ipairs(chunks) do
        if chunk[1]:find(text, 1, true) and type(chunk[2]) == "table" then
            return chunk[2][2], chunks
        end
    end
    return nil, chunks
end

function T.deleted_lines_are_highlighted_with_the_code_around_them()
    local lines = { "local t = {", "    f = function()", "        return 1", "    end,", "}" }
    h.repo(lines, h.edit(lines, { [2] = false }))
    local buf = h.open()
    vim.bo[buf].filetype = "lua"
    require("review.render").settled()
    local name, chunks = deleted_highlight(buf, "f", #lines)
    vim.bo[buf].filetype = ""
    assert(name == "@function.lua", vim.inspect(chunks))
end

-- Also apart from each other.
function T.deleted_lines_are_highlighted_in_the_languages_injected_in_them()
    local lines = { 'vim.cmd("resize 10")', "local a = 1", 'vim.cmd("resize 20")', "local b = 2" }
    h.repo(lines, { lines[2], lines[4] })
    local buf = h.open()
    vim.bo[buf].filetype = "lua"
    require("review.render").settled()
    local marks = h.marks(buf, "review_deleted", 1, #lines)
    local names = vim.tbl_map(function(mark)
        for _, chunk in ipairs(mark[4].virt_lines[1]) do
            if chunk[1] == "resize" and type(chunk[2]) == "table" then
                return chunk[2][2]
            end
        end
        return "none"
    end, marks)
    vim.bo[buf].filetype = ""
    assert(#names == 2 and names[1]:match("%.vim$") and names[2]:match("%.vim$"), vim.inspect(marks))
end

function T.deleted_lines_are_highlighted_again_when_the_filetype_changes()
    h.repo({ "local x = 1", "keep" }, { "keep" })
    local buf = h.open()
    vim.bo[buf].filetype = "lua"
    require("review.render").settled()
    local chunks = h.marks(buf, "review_deleted", 1, 1)[1][4].virt_lines[1]
    vim.bo[buf].filetype = ""
    assert(vim.iter(chunks):any(function(chunk)
        return type(chunk[2]) == "table" and chunk[2][2]:match("^@keyword")
    end), vim.inspect(chunks))
end

-- With signcolumn=auto the first sign widens the gutter only once it is drawn, after the render.
function T.deleted_lines_follow_the_gutter_when_signs_widen_it()
    h.repo(h.lines(20), h.lines(20))
    vim.wo.number, vim.wo.signcolumn = true, "auto"
    local buf = h.open()
    local before = textoff()
    h.keys("5Gccx\27")
    h.flush()
    local width = textoff()
    local drawn = gutter(buf)
    vim.wo.number, vim.wo.signcolumn = false, "yes"
    assert(width > before, ("gutter did not widen: %d"):format(width))
    assert(drawn == width, ("gutter %d, window %d"):format(drawn, width))
end

function T.the_cursor_line_number_keeps_its_highlight_on_changed_lines()
    h.repo(h.lines(5), h.edit(h.lines(5), { [3] = "mod 3" }))
    vim.wo.cursorline, vim.wo.cursorlineopt = true, "number"
    local buf = h.open()
    local function number_at(line)
        vim.api.nvim_win_set_cursor(0, { line, 0 })
        require("review.render").settled()
        for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
            if (mark[4].number_hl_group or ""):match("CursorNr$") then
                return mark[2] + 1, mark[4].number_hl_group
            end
        end
    end
    local changed_row, changed = number_at(3)
    local unchanged_row = number_at(1)
    vim.wo.cursorline, vim.wo.cursorlineopt = false, "both"
    local hl = vim.api.nvim_get_hl(0, { name = "ReviewAddCursorNr" })
    local cursor = vim.api.nvim_get_hl(0, { name = "CursorLineNr", link = false })
    local add = vim.api.nvim_get_hl(0, { name = "ReviewAddNr", link = false })
    assert(changed_row == 3 and changed == "ReviewAddCursorNr", tostring(changed))
    assert(unchanged_row == nil, "marked an unchanged line")
    assert(hl.fg == cursor.fg and hl.bg == add.bg, vim.inspect({ hl, cursor, add }))
end

function T.the_cursor_line_number_shows_only_in_its_window()
    h.repo(h.lines(12), h.edit(h.lines(12), { [3] = "mod 3", [5] = "mod 5", [10] = "mod 10" }))
    vim.wo.cursorline, vim.wo.cursorlineopt, vim.wo.number = true, "number", true
    -- Without colors, the number of a changed line looks like any other.
    vim.o.termguicolors = true
    vim.api.nvim_set_hl(0, "ReviewAddNr", { fg = "#0000ff", bg = "#00ff00" })
    vim.api.nvim_set_hl(0, "ReviewAddCursorNr", { fg = "#ff0000", bg = "#00ff00" })
    h.open()
    vim.cmd("normal! 3G")
    vim.cmd("split")
    vim.cmd("normal! 10G")
    require("review.render").settled()
    vim.cmd("redraw!")
    -- The highlight of the number of the line in the window.
    local function number(win, line)
        local pos = vim.fn.screenpos(win, line, 1)
        return vim.fn.screenattr(pos.row, pos.col - 2)
    end
    local top, bottom = unpack(vim.api.nvim_tabpage_list_wins(0))
    local plain = number(top, 5)
    local seen = { number(top, 3), number(top, 10), number(bottom, 3), number(bottom, 10) }
    vim.cmd("only")
    vim.wo.cursorline, vim.wo.cursorlineopt, vim.wo.number = false, "both", false
    vim.o.termguicolors = false
    vim.cmd.highlight("clear")
    require("review.highlights").set()
    assert(seen[1] == plain and seen[4] == plain, "the other window's cursor line number shows: " .. vim.inspect(seen))
    assert(seen[2] ~= plain and seen[3] ~= plain, "the cursor line number does not show: " .. vim.inspect(seen))
end

function T.diagnostic_signs_on_changed_lines_get_the_review_background()
    h.repo(h.lines(12), h.edit(h.lines(12), { [10] = "mod 10" }))
    h.review("file.txt")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_hl(0, "ReviewSignAdd", { fg = "#00ff00", bg = "#002200" })
    vim.api.nvim_set_hl(0, "ReviewSignLocalAdd", { fg = "#00ff00", bg = "#003300" })
    vim.api.nvim_set_hl(0, "DiagnosticSignError", { fg = "#ff0000" })
    local ns = vim.api.nvim_create_namespace("test_diagnostics")
    vim.api.nvim_set_hl(0, "ReviewAdd", { bg = "#004400" })
    vim.api.nvim_set_hl(0, "DiagnosticVirtualTextError", { fg = "#ff0000", bg = "#110000" })
    vim.diagnostic.config({ signs = true, virtual_text = true }, ns)
    local error = vim.diagnostic.severity.ERROR
    vim.diagnostic.set(ns, buf, {
        { lnum = 9, col = 0, message = "changed", severity = error },
        { lnum = 1, col = 0, message = "unchanged", severity = error },
    })
    local function groups()
        local found = {}
        local sign_ns = vim.diagnostic.get_namespace(ns).user_data.sign_ns
        for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, sign_ns, 0, -1, { details = true })) do
            found[mark[2] + 1] = mark[4].sign_hl_group
        end
        return found
    end
    local function texts(line)
        local virt_ns = vim.diagnostic.get_namespace(ns).user_data.virt_text_ns
        local mark = vim.api.nvim_buf_get_extmarks(buf, virt_ns, { line - 1, 0 }, { line - 1, -1 }, { details = true })[1]
        return vim.tbl_map(function(chunk)
            return chunk[2] or "none"
        end, mark[4].virt_text)
    end
    local virt = texts(10)
    local signs = groups()
    local hl = vim.api.nvim_get_hl(0, { name = signs[10] })
    local ok = signs[2] == "DiagnosticSignError" and hl.fg == 0xff0000 and hl.bg == 0x002200
    h.keys("2GAx")
    local edited = groups()
    local local_bg = vim.api.nvim_get_hl(0, { name = edited[2] }).bg
    h.keys("u")
    local undone = groups()
    require("review").stop()
    local stopped = groups()
    local stopped_virt = texts(10)
    vim.diagnostic.reset(ns)
    assert(ok, vim.inspect({ signs, hl }))
    assert(local_bg == 0x003300, vim.inspect(edited))
    assert(undone[2] == "DiagnosticSignError" and undone[10] == signs[10], vim.inspect(undone))
    assert(stopped[2] == "DiagnosticSignError" and stopped[10] == "DiagnosticSignError", vim.inspect(stopped))
    for _, group in ipairs(virt) do
        assert(vim.api.nvim_get_hl(0, { name = group, link = false }).bg == 0x004400, vim.inspect(virt))
    end
    assert(vim.tbl_contains(stopped_virt, "DiagnosticVirtualTextError"), vim.inspect(stopped_virt))
    assert(vim.api.nvim_get_hl(0, { name = virt[#virt], link = false }).fg == 0xff0000, vim.inspect(virt))
end

function T.diagnostic_virtual_lines_on_changed_lines_get_the_review_background()
    h.repo(h.lines(12), h.edit(h.lines(12), { [10] = "mod 10" }))
    h.review("file.txt")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_hl(0, "ReviewAdd", { bg = "#004400" })
    vim.api.nvim_set_hl(0, "DiagnosticVirtualLinesError", { fg = "#ff0000" })
    local ns = vim.api.nvim_create_namespace("test_virtual_lines")
    vim.diagnostic.config({ virtual_lines = true, virtual_text = false }, ns)
    vim.diagnostic.set(ns, buf, { { lnum = 9, col = 0, message = "changed", severity = vim.diagnostic.severity.ERROR } })
    local function chunks()
        local virt_ns = vim.diagnostic.get_namespace(ns).user_data.virt_lines_ns
        local mark = vim.api.nvim_buf_get_extmarks(buf, virt_ns, 0, -1, { details = true })[1]
        return mark[4].virt_lines, mark[4].virt_lines_leftcol
    end
    local changed, leftcol = chunks()
    require("review.diagnostics").apply(buf)
    local shown_again = #chunks()[1]
    require("review").stop()
    local stopped, stopped_leftcol = chunks()
    vim.diagnostic.reset(ns)
    assert(leftcol and not stopped_leftcol, "gutter not drawn in")
    for _, line in ipairs(changed) do
        assert(line[2][1]:match("^│") and line[2][2] == "ReviewSignAdd", vim.inspect(line))
        for i = 3, #line do
            local hl = vim.api.nvim_get_hl(0, { name = line[i][2], link = false })
            assert(hl.bg == 0x004400, vim.inspect(changed))
        end
        assert(line[#line][1]:match("^ +$"), "not padded")
    end
    assert(shown_again == #changed[1], "padded twice")
    for _, line in ipairs(stopped) do
        for _, chunk in ipairs(line) do
            assert(not (chunk[2] or ""):match("^Review"), vim.inspect(stopped))
        end
    end
end

function T.untracked_and_binary_files_are_not_rendered()
    h.repo(h.lines(3), h.lines(4))
    h.commit({ ["binary.bin"] = "a\0b" })
    h.write("binary.bin", "c\0d")
    h.write("untracked.txt", { "new" })
    h.open()
    for _, name in ipairs({ "binary.bin", "untracked.txt" }) do
        vim.cmd.edit(name)
        local buf = vim.api.nvim_get_current_buf()
        require("review.render").attach(buf)
        assert(not require("review.render").first_hunk(buf), name .. " attached")
        assert(#h.marks(buf, "review", 1, 2) == 0, name .. " has marks")
    end
end

-- Read with dos line endings, so the buffer has none of the carriage returns git has.
function T.crlf_files_only_show_the_changed_line()
    h.repo("a\r\nb\r\nc\r\n", "a\r\nchanged\r\nc\r\n")
    local buf = h.open()
    assert(vim.bo[buf].fileformat == "dos", vim.bo[buf].fileformat)
    local signed = vim.tbl_map(function(mark)
        return { mark[2], mark[4].end_row }
    end, h.marks(buf, "review", 1, 3))
    assert(vim.deep_equal(signed, { { 1, 1 } }), vim.inspect(signed))
end

function T.hunk_jumps_stop_at_the_first_and_last_hunk()
    h.repo(h.lines(30), h.edit(h.lines(30), { [5] = "mod 5", [15] = "mod 15", [25] = "mod 25" }))
    h.open()
    local function jump(keys)
        vim.cmd("normal " .. keys)
        return vim.fn.line(".")
    end
    vim.cmd("normal! 1G")
    local lines = { jump("]h"), jump("]h"), jump("]h"), jump("]h"), jump("[h"), jump("[h"), jump("[h") }
    assert(vim.deep_equal(lines, { 5, 15, 25, 25, 15, 5, 5 }), vim.inspect(lines))
end

-- An error in a callback stops the review once, instead of on every event after.
function T.an_error_stops_the_review_with_a_message()
    h.repo(h.lines(5), h.lines(6))
    h.review("file.txt")
    local diagnostics = require("review.diagnostics")
    local apply, notify, messages = diagnostics.apply, vim.notify, {}
    diagnostics.apply = function()
        error("broken")
    end
    vim.notify = function(message)
        table.insert(messages, message)
    end
    vim.cmd("doautocmd TextChanged")
    h.flush()
    diagnostics.apply, vim.notify = apply, notify
    local active = require("review").active()
    require("review").stop()
    assert(not active and #messages == 1 and messages[1]:find("broken"), vim.inspect({ active, messages }))
end

-- Starting the review notifies why it cannot, as a warning, which unlike an error does not fail the command.
local function warning(ref)
    local notify, notified = vim.notify, {}
    vim.notify = function(message, level)
        notified = { message, level }
    end
    require("review").start(ref)
    vim.notify = notify
    assert(notified[2] == vim.log.levels.WARN, vim.inspect(notified))
    return notified[1]
end

function T.an_invalid_ref_keeps_the_review()
    h.repo(h.lines(3), h.lines(4))
    h.review()
    local message = warning("nope")
    local session = require("review.session")
    local ref, open = session.ref, require("review.panel").is_open()
    require("review").stop()
    assert(ref == "dev" and open, vim.inspect({ ref, open }))
    assert(message == "Cannot review against nope: Not a valid object name nope", message)
end

function T.a_ref_without_shared_history_says_so()
    h.repo(h.lines(3), h.lines(4))
    h.git("checkout", "-q", "--orphan", "unrelated")
    h.git("commit", "-qm", "unrelated")
    require("review").stop()
    local message = warning("dev")
    assert(not require("review").active(), "started")
    assert(message == "HEAD shares no history with dev", message)
end

return T
