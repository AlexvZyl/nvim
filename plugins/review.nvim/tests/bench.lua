-- nvim --clean --headless -c "luafile tests/bench.lua", with N=lines for the size of the files, FILES=count for the
-- size of the review and FILTER=text to run the benchmarks with it in their name. PLUGIN_ROOT runs them against the
-- plugin there instead, like another revision of it.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(os.getenv("PLUGIN_ROOT") or root)
vim.opt.rtp:prepend(root .. "/../shared.nvim")
package.path = root .. "/?.lua;" .. package.path
vim.o.report = 10000
vim.notify = function(...) end
local h = require("tests.helpers")

-- At startup, in a new process each.
local cold = require("shared.bench").cold
cold("startup", 20, function()
    require("review").setup({})
end)
-- The first review started after startup, which loads the rest, with the file open and drawn.
cold("first start", 10, function()
    require("review").start("dev")
    vim.cmd.redraw()
end, function()
    require("review").setup({})
    local lines = h.lines(300)
    h.repo(lines, h.edit(lines, { [10] = "changed", [20] = false }), h.edit(lines, { [100] = { "added", "lines" } }))
    vim.cmd.edit("file.txt")
end)

-- Against the merge base, as reviewing files only changes what the since_review view shows.
require("review").setup({ view = "all" })
local render = require("review.render")

local function bench(name, count, fn)
    require("shared.bench").run(name, count, fn, "ms")
end

-- Lua lines, with every 7th changed and every 11th deleted by commits, then every 13th changed and every 17th
-- deleted locally.
local n = tonumber(os.getenv("N")) or 6000
local base, committed, working = {}, {}, {}
for i = 1, n do
    base[i] = ("local x%d = vim.fn.call(%d, 'str', { a = %d }) -- comment"):format(i, i, i)
    if i % 7 == 0 then
        table.insert(committed, "local changed = " .. i)
    elseif i % 11 ~= 0 then
        table.insert(committed, base[i])
    end
end
for i, line in ipairs(committed) do
    if i % 13 == 0 then
        table.insert(working, "local uncommitted = " .. i)
    elseif i % 17 ~= 0 then
        table.insert(working, line)
    end
end
h.repo(base, committed, working)
local buf = h.open()
vim.bo[buf].filetype = "lua"
vim.wo.wrap = false
vim.cmd("normal! " .. math.floor(n / 2) .. "G")

bench("attach", 5, function()
    render.attach(buf)
end)
-- With the deleted lines drawn and highlighted anew, which attach keeps when they show the same.
local deleted_namespace = vim.api.nvim_create_namespace("review_deleted")
bench("attach drawn", 5, function()
    vim.api.nvim_buf_clear_namespace(buf, deleted_namespace, 0, -1)
    render.attach(buf)
end)
bench("update", 20, function()
    render.update(buf)
end)
bench("type", 20, function()
    vim.cmd("normal! Ax")
    render.update(buf)
end)
bench("delete", 10, function()
    vim.cmd("normal! dd")
    render.update(buf)
    vim.cmd("silent normal! u")
    render.update(buf)
end)
bench("delete visual", 10, function()
    vim.cmd("normal! Vjd")
    render.update(buf)
    vim.cmd("silent normal! u")
    render.update(buf)
end)
-- Every line changed by one edit, like a substitute over the file or a formatter, is one hunk of all of them.
bench("substitute", 5, function()
    vim.cmd("silent %s/local/LOCAL/")
    render.update(buf)
    vim.cmd("silent normal! u")
    render.update(buf)
end)
vim.cmd("normal! " .. math.floor(n / 2) .. "G")
vim.cmd("normal! dd")
bench("repeat", 20, function()
    vim.cmd("normal! .")
    render.update(buf)
end)
-- A held repeat key deleting at the top, where the deleted lines pile up above the first line.
vim.cmd("normal! ggdd")
bench("repeat at top", 100, function()
    vim.cmd("normal! .")
    render.update(buf)
end)
vim.cmd("normal! " .. math.floor(n / 2) .. "G")
-- Every deleted line is drawn again for the new leftcol.
bench("scroll", 10, function()
    vim.cmd("normal! zl")
    render.settled()
end)
bench("settled", 200, render.settled)
bench("jump", 200, function()
    vim.cmd("normal ]h")
end)
-- The screen with the deleted lines on it.
bench("redraw", 50, function()
    vim.cmd("redraw!")
end)
-- Moving around, with the number of the cursor line highlighted like cursorlineopt=number, which marks it on
-- changed lines. Put back after, as the others run where they were.
local before = vim.fn.winsaveview()
vim.wo.cursorline, vim.wo.cursorlineopt = true, "number"
bench("move", 200, function()
    vim.cmd("normal! j")
    render.settled()
end)
-- Half a page at a time, drawing the deleted lines that come into view.
bench("scroll down", 50, function()
    vim.cmd("normal! \4")
    vim.cmd("redraw")
    render.settled()
end)
vim.wo.cursorline = false
vim.fn.winrestview(before)
render.settled()
-- Keeping the line in place measures the height of the wrapped lines.
vim.cmd("normal! 0")
vim.wo.wrap = true
bench("type wrapped", 20, function()
    vim.cmd("normal! Ax")
    render.update(buf)
end)
local diagnostics = {}
for row = 0, n - 1000, 3 do
    table.insert(diagnostics, { lnum = row, col = 0, message = "diagnostic", severity = 1 })
end
require("review.diagnostics").start()
local diagnostic_namespace = vim.api.nvim_create_namespace("bench")
vim.diagnostic.set(diagnostic_namespace, buf, diagnostics, { virtual_text = true })
bench("diagnosed", 10, function()
    vim.cmd("normal! Ax")
    render.update(buf)
end)
-- A language server publishing them again after an edit, which restyles those on changed lines.
bench("publish", 10, function()
    vim.diagnostic.set(diagnostic_namespace, buf, diagnostics, { virtual_text = true })
end)
require("review.diagnostics").stop()

-- A review of FILES files spread over directories, a few lines each: a quarter added, modified, deleted and left
-- as they are. With a file rewritten from scratch and a large one deleted.
local before, after, modified = { ["rewritten.lua"] = base, ["deleted.lua"] = base }, { ["rewritten.lua"] = working }, {}
for i = 1, tonumber(os.getenv("FILES")) or 500 do
    local name = ("file%d.lua"):format(i)
    local path = ("dir%d/sub%d/%s"):format(i % 20, i % 3, name)
    local lines = h.lines(i % 30 + 10)
    before[path] = i % 4 ~= 0 and lines or nil
    after[path] = i % 4 == 1 and h.edit(lines, { [3] = "changed", [5] = false }) or i % 4 ~= 2 and lines or nil
    if i % 4 == 1 then
        table.insert(modified, name)
    end
end
vim.cmd("silent! %bwipeout!")
h.git("checkout", "-q", "-f", "dev")
h.commit(before)
h.git("checkout", "-q", "branch")
h.git("merge", "-q", "--no-edit", "dev")
for path in pairs(before) do
    if not after[path] then
        os.remove(path)
    end
end
h.commit(after)
local main, panel, panel_buf = h.review()
local review = require("review")

bench("start", 5, function()
    review.stop()
    review.start("dev")
end)
-- With the blobs of the files, which the review reads once needed.
bench("load", 10, function()
    local session = require("review.session")
    session.load()
    require("review.state").pending(session.files[1].key)
end)
-- What the watcher does once git moved HEAD.
bench("refresh", 10, require("review.watch").refresh)
bench("panel", 20, require("review.panel").refresh)
bench("toggle", 10, function()
    review.panel()
    review.panel()
end)
-- Marking files reviewed saves the state and draws the panel again.
bench("mark", 10, function()
    h.press("ddu")
end)
bench("mark lines", 10, function()
    h.press("V4jdu")
end)
h.press("ddu")
bench("redo", 10, function()
    h.press("<C-r>u")
end)
-- Opening a file not opened before reads and renders it. Started again, as toggling made new windows.
main, panel, panel_buf = h.review()
local opened = 0
bench("open", 20, function()
    opened = opened + 1
    h.pick(" " .. modified[opened])
end)
-- Going back and forth between files opened, which the panel follows.
h.pick(" " .. modified[1])
h.pick(" " .. modified[2])
vim.api.nvim_set_current_win(main)
bench("switch", 20, function()
    vim.cmd("buffer #")
    vim.cmd("redraw")
end)
-- Wiped first, in another buffer so its window stays.
local scratch = vim.api.nvim_create_buf(false, true)
bench("open deleted", 10, function()
    local deleted = require("review.deleted")
    vim.api.nvim_win_set_buf(main, scratch)
    deleted.wipe()
    vim.api.nvim_win_set_buf(main, deleted.open("deleted.lua"))
end)
vim.api.nvim_set_current_win(main)
vim.cmd.edit("rewritten.lua")
bench("attach rewritten", 5, function()
    render.attach(vim.api.nvim_get_current_buf())
end)
-- Every buffer open again once HEAD moved, with 50 of the files open.
for i = 1, 50 do
    vim.fn.bufload(vim.fn.bufadd(require("review.session").files[i].path))
end
bench("attach all", 10, render.attach_all)
vim.api.nvim_set_current_win(panel)
-- Diffed against as reviewed, marking a file reviewed attaches its buffer again. One of those opened.
review.view("since_review")
vim.fn.cursor(vim.fn.search(" " .. modified[1] .. "$"), 1)
bench("mark since review", 10, function()
    h.press("ddu")
end)
review.view("all")
bench("panel redraw", 50, function()
    vim.api.nvim_buf_call(panel_buf, function()
        vim.cmd("redraw!")
    end)
end)
review.stop()
require("shared.bench").finish()
