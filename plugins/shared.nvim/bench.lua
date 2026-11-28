-- nvim -l plugins/shared.nvim/bench.lua [--runs N] [--base REV] [plugin.nvim ...]
--
-- Runs the benchmarks of the plugins, all by default, against the base revision (main by default), checked out in a
-- worktree. Both run N times each, in turn, in new processes, so they see the machine the same. Each side runs its
-- own benchmarks, and only benchmarks both have are compared, by the Mann-Whitney U test on the medians of the runs.
-- The p-values are adjusted for testing every benchmark at once, which takes 10 runs or so to show anything.
-- The calibrate benchmark does the same work on both sides, so a change in it is the machine, not the code.
local shared = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
vim.opt.rtp:prepend(shared)
local stats = require("shared.stats")
local plugins_dir = vim.fs.dirname(shared)

local options = { plugins = {}, base = "main" }
local i = 1
while i <= #arg do
    if arg[i] == "--runs" or arg[i] == "--base" then
        options[arg[i]:sub(3)] = arg[i + 1]
        i = i + 1
    else
        table.insert(options.plugins, (arg[i]:gsub("/$", "")))
    end
    i = i + 1
end
options.runs = tonumber(options.runs) or 10
if #options.plugins == 0 then
    for _, bench in ipairs(vim.fn.glob(plugins_dir .. "/*/tests/bench.lua", false, true)) do
        table.insert(options.plugins, vim.fn.fnamemodify(bench, ":h:h:t"))
    end
end

local function git(...)
    local result = vim.system({ "git", "-C", plugins_dir, ... }, { text = true }):wait()
    assert(result.code == 0, table.concat({ "git", ... }, " ") .. ": " .. result.stderr)
    return vim.trim(result.stdout)
end

-- On CPUs with performance and efficiency cores, only the performance ones, as runs take longer on the others.
local pinned
local performance = io.open("/sys/devices/cpu_core/cpus")
if performance then
    pinned = vim.fn.executable("taskset") == 1 and vim.trim(performance:read("a")) or nil
    performance:close()
end

-- The benchmarks in the plugin directory, by name, in a new process.
local function run(plugin_dir)
    local out = vim.fn.tempname()
    local command = { vim.v.progpath, "--clean", "--headless", "-c", "luafile tests/bench.lua", "-c", "cq" }
    if pinned then
        command = vim.list_extend({ "taskset", "-c", pinned }, command)
    end
    local result = vim.system(command, { cwd = plugin_dir, env = { BENCH_OUT = out }, text = true }):wait()
    assert(result.code == 0, plugin_dir .. " benchmarks failed:\n" .. result.stdout .. result.stderr)
    local file = assert(io.open(out))
    local results = vim.json.decode(file:read("a"))
    file:close()
    os.remove(out)
    return results
end

-- Adds each benchmark's median and fastest time.
local function add(into, results)
    for name, result in pairs(results) do
        into[name] = into[name] or { unit = result.unit, order = result.order, medians = {}, min = math.huge }
        table.insert(into[name].medians, result.median)
        into[name].min = math.min(into[name].min, result.min)
    end
end

local function report(plugin, current, base)
    io.stdout:write(("\n%s, %d runs against %s\n"):format(plugin, options.runs, options.base))
    io.stdout:write(("%-20s %10s %7s %10s %8s %8s\n"):format("", "median", "spread", "base", "change", "p"))
    local names = vim.tbl_keys(current)
    table.sort(names, function(a, b)
        return current[a].order < current[b].order
    end)
    -- Calibrate is about the machine, so it is not among the compared.
    local compared, ps = {}, {}
    for _, name in ipairs(names) do
        if base[name] and name ~= "calibrate" then
            compared[name] = stats.compare(base[name].medians, current[name].medians)
            table.insert(ps, compared[name].p)
        end
    end
    local adjusted = stats.holm(ps)
    -- The smallest p-value the runs can give, adjusted like the largest.
    local fewest = vim.fn.range(1, options.runs)
    local farthest_apart = vim.tbl_map(function(x)
        return x + options.runs
    end, fewest)
    if #ps > 0 and stats.mann_whitney(fewest, farthest_apart) * #ps >= 0.05 then
        io.stdout:write(("Too few runs for %d benchmarks to ever differ significantly, take more with --runs.\n"):format(#ps))
    end
    for _, name in ipairs(names) do
        local now = current[name]
        local line = ("%-20s %7.2f %-2s %6.1f%%"):format(name, stats.median(now.medians), now.unit, stats.spread(now.medians) * 100)
        if compared[name] then
            compared[name].p = table.remove(adjusted, 1)
            local verdict = stats.verdict(compared[name])
            local change = (compared[name].ratio - 1) * 100
            line = line .. ("%10.2f %+7.1f%% %8.4f  %s"):format(stats.median(base[name].medians), change, compared[name].p, verdict ~= "same" and verdict or "")
        elseif not base[name] then
            line = line .. "       new"
        end
        io.stdout:write(line .. "\n")
    end
    for name in pairs(base) do
        if not current[name] then
            io.stdout:write(("%-20s removed\n"):format(name))
        end
    end
    local calibration = base.calibrate and stats.compare(base.calibrate.medians, current.calibrate.medians)
    if calibration and stats.verdict(calibration, 0.05) ~= "same" then
        io.stdout:write(("Calibration is %+.1f%%: the machine changed during the runs, so the changes may not be the code's.\n"):format((calibration.ratio - 1) * 100))
    end
end

local worktree = vim.fn.tempname()
git("worktree", "add", "--quiet", "--detach", worktree, options.base)
local ok, err = pcall(function()
    local base_plugins = worktree .. "/" .. vim.fs.relpath(git("rev-parse", "--show-toplevel"), plugins_dir)
    for _, plugin in ipairs(options.plugins) do
        local base_dir = base_plugins .. "/" .. plugin
        if vim.uv.fs_stat(base_dir .. "/tests/bench.lua") then
            local current, base = {}, {}
            for r = 1, options.runs do
                io.stderr:write(("\r\27[K%s %d/%d"):format(plugin, r, options.runs))
                -- Alternates which goes first.
                if r % 2 == 0 then
                    add(base, run(base_dir))
                end
                add(current, run(plugins_dir .. "/" .. plugin))
                if r % 2 == 1 then
                    add(base, run(base_dir))
                end
            end
            io.stderr:write("\r\27[K")
            report(plugin, current, base)
        else
            io.stdout:write(("\n%s has no benchmarks at %s\n"):format(plugin, options.base))
        end
    end
end)
git("worktree", "remove", "--force", worktree)
assert(ok, err)
