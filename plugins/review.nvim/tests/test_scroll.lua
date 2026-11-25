local h = require("tests.helpers")

local T = {}

-- Committed hunks of every kind: lines deleted, modified, added, and modified with more lines added.
local function setup()
    h.repo(h.lines(100), h.edit(h.lines(100), {
        [20] = false,
        [21] = false,
        [31] = "mod 31",
        [32] = "mod 32",
        [40] = { "line 40", "add 40a", "add 40b" },
        [50] = { "mod 50", "add 50" },
    }))
    return h.open()
end

-- Lines around each hunk, and how far below the top of the window the cursor starts.
local LINES = { 5, 18, 19, 20, 28, 29, 30, 31, 33, 38, 39, 40, 41, 42, 47, 48, 49, 50, 51, 70 }
local OFFSETS = { 0, 1, 2, 5, 30 }

local function each_position(fn)
    local failures = {}
    for _, line in ipairs(LINES) do
        for _, offset in ipairs(OFFSETS) do
            h.place(line, offset)
            local err = fn(line, offset)
            if err then
                table.insert(failures, ("line %d offset %d: %s"):format(line, offset, err))
            end
        end
    end
    assert(#failures == 0, #failures .. " failed\n" .. table.concat(failures, "\n"))
end

local function same_top(a, b)
    return a.top == b.top and a.fill == b.fill
end

local function describe(a, b)
    return ("top %d/%d row %d -> top %d/%d row %d"):format(a.top, a.fill, a.row, b.top, b.fill, b.row)
end

-- An edit then its undo, checking the view after both. The selection is made first, as it can scroll.
local function edit(keys, check, settle, select, undo_check)
    setup()
    each_position(function()
        if select then
            vim.cmd("normal! " .. select)
            vim.cmd("redraw")
            require("review.render").settled()
            require("review.scroll").key()
        end
        local before = h.view()
        h.keys(keys, settle)
        local after = h.view()
        local err = check(before, after)
        h.keys("u", settle)
        if err then
            return keys .. ": " .. err
        end
        local undone = h.view()
        local undo_err = undo_check and undo_check(after, undone)
        if undo_check == nil and not same_top(before, undone) then
            undo_err = describe(before, undone)
        end
        if undo_err then
            return "undo: " .. undo_err
        end
    end)
end

-- Showing more above the top line when the deleted lines come there.
local function keeps_top(before, after)
    return (before.top ~= after.top or after.fill < before.fill) and describe(before, after) or nil
end

local function keeps_row(before, after)
    return before.row ~= after.row and describe(before, after) or nil
end

-- With the top in place, and further when deleted lines come to sit above the new line.
local function moves_down(before, after)
    return (after.row <= before.row or not same_top(before, after)) and describe(before, after) or nil
end

function T.typing_keeps_the_line_in_place()
    edit("Ax", keeps_row)
end

-- Commenting replaces the lines through the API, rather than editing them in place like typing.
function T.commenting_a_line_keeps_the_cursor_on_its_row()
    local buf = setup()
    vim.bo[buf].commentstring = "# %s"
    each_position(function()
        local before = h.view()
        h.keys("gcc", true, true)
        local after = h.view()
        h.keys("u")
        local undone = h.view()
        if before.row ~= after.row then
            return describe(before, after)
        elseif not same_top(before, undone) then
            return "undo: " .. describe(before, undone)
        end
    end)
end

-- Like any edit of more lines, scrolling as much is jarring.
function T.commenting_lines_keeps_the_screen_in_place()
    local buf = setup()
    vim.bo[buf].commentstring = "# %s"
    each_position(function()
        local before = h.view()
        h.keys("gcj", true, true)
        local after = h.view()
        h.keys("u")
        return keeps_top(before, after) or not same_top(before, h.view()) and "undo: " .. describe(before, h.view()) or nil
    end)
end

function T.deleting_a_line_keeps_the_cursor_on_its_row()
    edit("dd", keeps_row)
end

function T.deleting_a_selection_of_one_line_keeps_the_cursor_on_its_row()
    edit("d", keeps_row, nil, "V")
end

-- Deleting one of two lines that are the same could be deleting either.
function T.deleting_one_of_the_same_lines_keeps_the_cursor_on_its_row()
    h.repo(h.lines(30), h.edit(h.lines(30), { [10] = { "", "" }, [20] = false }))
    h.open()
    for _, line in ipairs({ 10, 11 }) do
        h.place(line, 5)
        local before = h.view()
        h.keys("dd")
        local after = h.view()
        h.keys("u")
        assert(before.row == after.row, line .. ": " .. describe(before, after))
    end
end

-- Two lines from one, as undone the line comes back where it was.
function T.breaking_a_line_keeps_the_screen_in_place()
    edit("0li\r\27", keeps_top)
end

function T.deleting_the_last_line_keeps_the_screen_in_place()
    setup()
    vim.cmd("normal! Gzb")
    local before = h.view()
    h.keys("dd")
    local after = h.view()
    assert(same_top(before, after), describe(before, after))
end

-- Lines deleted at the top of the window show above it, and go once that is undone.
function T.deleting_lines_at_the_top_shows_them()
    setup()
    for _, line in ipairs({ 5, 30, 70 }) do
        h.place(line, 0)
        h.keys("dj")
        local view = h.view()
        assert(view.top == line and view.fill == 2 and view.row == 3, line .. ": " .. vim.inspect(view))
        h.keys("u")
        view = h.view()
        assert(view.top == line and view.fill == 0 and view.row == 1, line .. " undo: " .. vim.inspect(view))
    end
end

-- An edit of another line, like by a formatter, is not the cursor's to keep in place, so the screen stays.
function T.an_edit_above_keeps_the_screen_still()
    local buf = setup()
    each_position(function(line)
        local before = h.view()
        vim.api.nvim_buf_set_lines(buf, line - 3, line - 2, true, { "changed" })
        require("review.render").update(buf)
        h.flush()
        local after = h.view()
        h.keys("u")
        return line > 3 and keeps_top(before, after) or nil
    end)
end

-- Typed in the main loop, through the autocmds that render, settle and restyle.
function T.typed_keys_keep_the_line_in_place_and_scroll_the_deleted_lines()
    h.repo(h.lines(100), h.edit(h.lines(100), { [50] = false }))
    local main = h.review("file.txt")
    vim.api.nvim_set_current_win(main)
    vim.wo.wrap = false
    h.input("60Gzt5j")
    local before = h.view()
    h.input("dd")
    local after = h.view()
    h.input("u45Gztzl")
    local chunks = h.marks(vim.api.nvim_get_current_buf(), "review_deleted", 50, 50)[1][4].virt_lines[1]
    require("review").stop()
    assert(before.row == after.row, describe(before, after))
    assert(chunks[3][1]:sub(1, 6) == "ine 50", vim.inspect(chunks))
end

function T.deleting_down_with_a_motion_drops_the_cursor_below()
    edit("dj", function(before, after)
        return (keeps_top(before, after) or after.line ~= before.line) and describe(before, after) or nil
    end)
end

-- Like a selection up, the cursor goes on the line above the deleted lines.
local function deletes_up(keys, count)
    edit(keys, function(before, after)
        local line = math.max(before.line - count, 1)
        local top = before.top > line and line or before.top
        return (after.top ~= top or after.line ~= line) and describe(before, after) .. " line " .. after.line or nil
    end, nil, nil, function(after, undone)
        return after.top ~= undone.top and describe(after, undone) or nil
    end)
end

-- Typed faster than the screen settles, only the key handler sees where the selection started.
function T.a_selection_up_typed_fast_puts_the_cursor_above()
    local buf = setup()
    local main = vim.api.nvim_get_current_win()
    h.start()
    vim.api.nvim_set_current_win(main)
    h.place(60, 10)
    vim.api.nvim_feedkeys("jjVkkkkd", "xt", false)
    require("review.render").update(buf)
    h.flush()
    local line = vim.fn.line(".")
    require("review").stop()
    assert(line == 57, line)
end

function T.deleting_up_with_a_motion_puts_the_cursor_above()
    deletes_up("dk", 2)
end

function T.deleting_up_with_a_count_puts_the_cursor_above()
    deletes_up("d2k", 3)
end

function T.deleting_a_selection_down_keeps_the_screen_in_place()
    edit("d", keeps_top, nil, "Vjj")
end

function T.deleting_a_selection_up_puts_the_cursor_above_it()
    edit("d", function(before, after)
        local line = math.max(before.line - 1, 1)
        -- Unless the selection starts at the top, where the line above has to be scrolled to.
        local top = before.top == before.line and line or before.top
        local moved = after.top ~= top or after.line ~= line
        return moved and describe(before, after) .. " line " .. after.line or nil
    end, nil, "Vkk", function(after, undone)
        return after.top ~= undone.top and describe(after, undone) or nil
    end)
end

-- Typed fast the screen does not settle in visual mode, only the key handler sees where the cursor was.
local function delete_selection_fast(select)
    setup()
    local results = {}
    for _, line in ipairs({ 30, 60, 80 }) do
        h.place(line, 10)
        local before = h.view()
        vim.cmd("normal! " .. select)
        require("review.scroll").key()
        h.keys("d")
        table.insert(results, { before = before, after = h.view() })
        h.keys("u")
    end
    return results
end

function T.deleting_a_selection_down_typed_fast_keeps_the_screen_in_place()
    for _, result in ipairs(delete_selection_fast("Vjj")) do
        local before, after = result.before, result.after
        assert(after.top == before.top and after.line == before.line, describe(before, after))
    end
end

function T.deleting_a_selection_up_typed_fast_puts_the_cursor_above_it()
    for _, result in ipairs(delete_selection_fast("Vkk")) do
        local before, after = result.before, result.after
        assert(after.top == before.top and after.line == before.line - 3, describe(before, after))
    end
end

function T.opening_a_line_below_moves_the_cursor_down()
    edit("o", moves_down)
end

function T.opening_a_line_above_keeps_the_screen_above_in_place()
    edit("O", keeps_top)
end

local function paste(keys, check)
    setup()
    vim.cmd("normal! 1Gyy")
    each_position(function()
        local before = h.view()
        h.keys(keys)
        local err = check(before, h.view())
        h.keys("u")
        return err
    end)
end

function T.pasting_below_moves_the_cursor_down()
    paste("p", moves_down)
end

function T.pasting_above_keeps_the_screen_above_in_place()
    paste("P", keeps_top)
end

-- A held repeat key, in a main loop that redraws and scrolls between the keys, never draws the deleted lines out of
-- the window's gutter.
function T.repeating_a_delete_keeps_the_deleted_lines_in_the_gutter()
    local script = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/typed.lua"
    local result = vim.system({ vim.v.progpath, "--clean", "--headless", "-c", "luafile " .. script }, { text = true, timeout = 10000 }):wait()
    local ok, typed = pcall(vim.json.decode, result.stdout or "")
    assert(ok and typed.redraws > 50 and typed.misdrawn == 0, (result.stdout or "") .. (result.stderr or ""))
end

-- Spamming dd and u must not scroll the buffer away, settled between keys or not.
local function no_drift(settle)
    setup()
    each_position(function()
        local before = h.view()
        for _ = 1, 3 do
            h.keys("dd", settle)
            h.keys("u", settle)
        end
        local after = h.view()
        if not same_top(before, after) or before.row ~= after.row then
            return describe(before, after)
        end
    end)
end

function T.delete_and_undo_does_not_drift()
    no_drift(true)
end

function T.delete_and_undo_typed_fast_does_not_drift()
    no_drift(false)
end

return T
