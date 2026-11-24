-- nvim --clean --headless -c "luafile tests/bench.lua", with N=lines for the size of the file.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
package.path = root .. "/?.lua;" .. package.path
require("review").setup({})
local h = require("tests.helpers")
local render = require("review.render")

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

local function bench(name, count, fn)
    collectgarbage()
    local start = vim.uv.hrtime()
    for _ = 1, count do
        fn()
    end
    io.stdout:write(("%-10s %8.2f ms\n"):format(name, (vim.uv.hrtime() - start) / 1e6 / count))
end

bench("attach", 5, function()
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
vim.cmd("normal! dd")
bench("repeat", 20, function()
    vim.cmd("normal! .")
    render.update(buf)
end)
bench("scroll", 10, function()
    vim.cmd("normal! zl")
    render.update(buf)
end)
bench("settled", 200, render.settled)
local diagnostics = {}
for row = 0, n - 1000, 3 do
    table.insert(diagnostics, { lnum = row, col = 0, message = "diagnostic", severity = 1 })
end
require("review.diagnostics").start()
vim.diagnostic.set(vim.api.nvim_create_namespace("bench"), buf, diagnostics, { virtual_text = true })
bench("diagnosed", 10, function()
    vim.cmd("normal! Ax")
    render.update(buf)
end)
vim.cmd("qa!")
