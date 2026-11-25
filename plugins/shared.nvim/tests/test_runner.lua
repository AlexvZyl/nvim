local T = {}

local shared = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

-- Runs a plugin with a test of the body in a new process, which the runner exits.
local function exit_code(body)
    local root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/tests", "p")
    vim.fn.writefile({ "return { test = function() " .. body .. " end }" }, root .. "/tests/test_it.lua")
    local run = ("lua vim.opt.rtp:prepend(%q) require('shared.test').run(%q)"):format(shared, root)
    return vim.system({ vim.v.progpath, "--clean", "--headless", "-c", run }, { timeout = 10000 }):wait().code
end

-- CI goes by it.
function T.the_exit_code_is_whether_the_tests_passed()
    local passed, failed = exit_code(""), exit_code("error('x')")
    assert(passed == 0 and failed == 1, vim.inspect({ passed, failed }))
end

return T
