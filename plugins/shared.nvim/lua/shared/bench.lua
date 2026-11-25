-- Times benchmarks in a plugin's tests/bench.lua, which ends with finish(). Run by itself it prints the timings, run
-- by the runner it also writes them to BENCH_OUT. With FILTER=text only the ones with it in their name run.
local M = {}

local filter = os.getenv("FILTER")
local out = os.getenv("BENCH_OUT")
local units = { ms = 1e6, us = 1e3 }

-- By name, the median and fastest run in the unit, and the order they ran in.
local results = {}

-- Times each run of the function once warmed up, printing the median and the fastest in the unit.
function M.run(name, count, fn, unit)
    if filter and not name:find(filter, 1, true) then
        return
    end
    if not next(results) then
        io.stdout:write(("%-16s %8s %8s\n"):format("", "median", "min"))
    end
    -- Until the JIT compiled it and caches filled, for a while but at most as many times as it is timed.
    local warm, deadline = 0, vim.uv.hrtime() + 20e6
    repeat
        fn()
        warm = warm + 1
    until warm >= count or vim.uv.hrtime() > deadline
    collectgarbage()
    local times = {}
    for i = 1, count do
        local start = vim.uv.hrtime()
        fn()
        times[i] = (vim.uv.hrtime() - start) / units[unit]
    end
    table.sort(times)
    local median = times[math.ceil(count / 2)]
    results[name] = { unit = unit, median = median, min = times[1], order = vim.tbl_count(results) + 1 }
    io.stdout:write(("%-16s %8.2f %8.2f %s\n"):format(name, median, times[1], unit))
end

-- The same work on every run of every plugin, so a change in it is the machine and not the code.
local function calibrate()
    local lines = {}
    for i = 1, 2000 do
        lines[i] = ("line %d %s"):format(i, string.rep("x", i % 50))
    end
    local before = table.concat(lines, "\n")
    lines[1000] = "changed"
    local after = table.concat(lines, "\n")
    M.run("calibrate", 50, function()
        vim.text.diff(before, after)
        local numbers = {}
        for i = 1, 20000 do
            numbers[i] = (i * 7919) % 20000
        end
        table.sort(numbers)
    end, "ms")
end

-- Writes the results for the runner and quits.
function M.finish()
    if out then
        filter = nil
        calibrate()
        local file = assert(io.open(out, "w"))
        file:write(vim.json.encode(results))
        file:close()
    end
    vim.cmd("qa!")
end

return M
