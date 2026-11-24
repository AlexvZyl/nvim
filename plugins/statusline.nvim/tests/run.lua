-- nvim --clean --headless -c "luafile tests/run.lua", with FILTER=text to run the tests with it in their name.
-- Each test runs in the main loop, where typed keys change the mode, and can wait for it.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
package.path = root .. "/?.lua;" .. package.path
vim.o.report, vim.o.showmode = 10000, false
require("statusline").setup({
    toggles = {
        {
            enabled = function()
                return true
            end,
            icon = "on",
        },
        {
            enabled = function()
                return false
            end,
            icon = "off",
        },
    },
})

local filter = os.getenv("FILTER")
local tests = {}
for _, file in ipairs(vim.fn.glob(root .. "/tests/test_*.lua", false, true)) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    local module = dofile(file)
    local names = vim.tbl_keys(module)
    table.sort(names)
    for _, test in ipairs(names) do
        local full = name .. ": " .. test
        if not filter or full:find(filter, 1, true) then
            table.insert(tests, { name = full, fn = module[test] })
        end
    end
end

local failed, passed = 0, 0
local function run(i)
    local test = tests[i]
    if not test then
        io.stdout:write(("\n%d passed, %d failed\n"):format(passed, failed))
        os.exit(failed == 0 and 0 or 1)
    end
    vim.cmd("silent! %bwipeout!")
    coroutine.wrap(function()
        local ok, err = pcall(test.fn)
        if ok then
            passed = passed + 1
            io.stdout:write("ok    " .. test.name .. "\n")
        else
            failed = failed + 1
            io.stdout:write("FAIL  " .. test.name .. "\n" .. tostring(err):gsub("^", "      "):gsub("\n", "\n      ") .. "\n")
        end
        vim.schedule(function()
            run(i + 1)
        end)
    end)()
end
vim.schedule(function()
    run(1)
end)
