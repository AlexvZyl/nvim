-- nvim --clean --headless -c "luafile tests/run.lua", with FILTER=text to run the tests with it in their name.
-- Not -l, which does not resize the window to the size the tests set.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
package.path = root .. "/?.lua;" .. package.path
vim.o.showmode = false
-- Messages would print in the middle of the results, like "5 fewer lines".
vim.o.report = 10000
vim.notify = function(message)
    io.stdout:write("      " .. message .. "\n")
end
require("review").setup({})

local filter = os.getenv("FILTER")
local failed, passed = 0, 0
for _, file in ipairs(vim.fn.glob(root .. "/tests/test_*.lua", false, true)) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    local tests = dofile(file)
    local names = vim.tbl_keys(tests)
    table.sort(names)
    for _, test in ipairs(names) do
        local full = name .. ": " .. test
        if not filter or full:find(filter, 1, true) then
            local ok, err = pcall(tests[test])
            if ok then
                passed = passed + 1
                io.stdout:write("ok    " .. full .. "\n")
            else
                failed = failed + 1
                io.stdout:write("FAIL  " .. full .. "\n" .. tostring(err):gsub("^", "      "):gsub("\n", "\n      ") .. "\n")
            end
        end
    end
end
io.stdout:write(("\n%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
