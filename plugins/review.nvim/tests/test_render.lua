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
    assert(mark[4].line_hl_group == "ReviewAdd")
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

-- Tabs take the tabstop and the text scrolls with the window, a cell at a time.
function T.deleted_lines_expand_tabs_and_scroll()
    h.repo({ "\tcafé x", "keep" }, { "keep" })
    local buf = h.open()
    vim.bo[buf].tabstop, vim.wo.wrap = 4, false
    local function text(leftcol)
        vim.fn.winrestview({ leftcol = leftcol })
        require("review.render").update(buf)
        local chunks = h.marks(buf, "review_deleted", 1, 1)[1][4].virt_lines[1]
        return table.concat(vim.tbl_map(function(chunk)
            return chunk[1]
        end, vim.list_slice(chunks, 3, #chunks - 1)))
    end
    local shown = { text(0), text(2), text(5) }
    vim.wo.wrap = true
    assert(vim.deep_equal(shown, { "    café x", "  café x", "afé x" }), vim.inspect(shown))
end

-- Without a line break at the end the last line is not changed.
function T.a_file_without_a_line_break_at_the_end_is_unchanged()
    h.repo({ "a", "b" }, { "a", "b" })
    local file = assert(io.open("file.txt", "wb"))
    file:write("a\nb\nc")
    file:close()
    h.git("commit", "-qam", "no line break")
    local buf = h.open()
    local mark = h.marks(buf, "review", 3, 3)[1]
    assert(mark and mark[4].sign_text == "│ ", vim.inspect(mark))
    assert(#h.marks(buf, "review_deleted", 1, 3) == 0, vim.inspect(h.marks(buf, "review_deleted", 1, 3)))
end

function T.edits_rerender()
    h.repo(h.lines(12), h.lines(12))
    local buf = h.open()
    assert(#h.marks(buf, "review", 1, 12) == 0)
    vim.cmd("normal! 3G")
    h.keys("Ax")
    local mark = find(buf, "review", 3)
    assert(mark and mark[4].sign_hl_group == "ReviewSignLocalAdd", vim.inspect(mark))
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
    vim.fn.cursor(vim.fn.search("file.txt$"), 1)
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    local topfill = vim.api.nvim_win_call(main, vim.fn.winsaveview).topfill
    require("review").stop()
    assert(topfill == 2, topfill)
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
    local width = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff
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
    local width = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff
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
    local before = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff
    h.keys("5Gccx\27")
    h.flush()
    local width = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].textoff
    local drawn = gutter(buf)
    vim.wo.number, vim.wo.signcolumn = false, "yes"
    assert(width > before, ("gutter did not widen: %d"):format(width))
    assert(drawn == width, ("gutter %d, window %d"):format(drawn, width))
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
    local function binary(text)
        local file = assert(io.open("binary.bin", "wb"))
        file:write(text)
        file:close()
    end
    binary("a\0b")
    h.git("add", "binary.bin")
    h.git("commit", "-qm", "binary")
    binary("c\0d")
    vim.fn.writefile({ "new" }, "untracked.txt")
    h.open()
    for _, name in ipairs({ "binary.bin", "untracked.txt" }) do
        vim.cmd.edit(name)
        local buf = vim.api.nvim_get_current_buf()
        require("review.render").attach(buf)
        assert(not require("review.render").first_hunk(buf), name .. " attached")
        assert(#h.marks(buf, "review", 1, 2) == 0, name .. " has marks")
    end
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

function T.an_invalid_ref_keeps_the_review()
    h.repo(h.lines(3), h.lines(4))
    h.review()
    local notify = vim.notify
    vim.notify = function() end
    require("review").start("nope")
    vim.notify = notify
    local session = require("review.session")
    local ref, open = session.ref, require("review.panel").is_open()
    require("review").stop()
    assert(ref == "dev" and open, vim.inspect({ ref, open }))
end

return T
