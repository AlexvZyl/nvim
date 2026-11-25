-- nvim -l plugins/shared.nvim/bench.lua [--runs N] [--base REV] [--save | --history] [plugin.nvim ...]
--
-- Runs the benchmarks of the plugins, all of them by default, N times each in a new process, and compares the
-- median of every run with a base by the Mann-Whitney U test:
--   --base REV  the plugins at the revision, in a worktree, run in turn with the current ones on this machine now,
--               by the current benchmarks, so the revision needs what they call.
--   (default)   the latest results saved on this machine, as timings from other hardware say nothing.
--   --save      saves the results to the plugin's tests/results/<machine>/.
--   --history   prints the medians of the results saved on this machine instead, the latest last.
-- The p-values are adjusted for testing every benchmark at once, which takes 10 runs or so to show anything.
-- The calibrate benchmark does the same work on every revision, so a change in it is the machine, like it being
-- busy, hotter or on another power profile, and the other changes are not to be trusted. So does how they ran:
-- the Neovim version, the OS and the cores, only the performance ones on CPUs with efficiency ones too.
local shared = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
vim.opt.rtp:prepend(shared)
local stats = require("shared.stats")
local plugins_dir = vim.fs.dirname(shared)

local options = { plugins = {} }
local i = 1
while i <= #arg do
    if arg[i] == "--runs" or arg[i] == "--base" then
        options[arg[i]:sub(3)] = arg[i + 1]
        i = i + 1
    elseif arg[i] == "--save" or arg[i] == "--history" then
        options[arg[i]:sub(3)] = true
    else
        table.insert(options.plugins, (arg[i]:gsub("/$", "")))
    end
    i = i + 1
end
options.runs = tonumber(options.runs) or 10
-- The benchmarks filtered out leave the state the next ones run in, like the edits they made.
local filter = os.getenv("FILTER")
assert(not (filter and options.save), "FILTER only runs some of the benchmarks, so their results are not saved")
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

local cpus, uname = vim.uv.cpu_info(), vim.uv.os_uname()
local machine = {
    cpu = vim.trim(cpus[1].model),
    cores = #cpus,
    os = uname.sysname .. " " .. uname.release,
    nvim = tostring(vim.version()),
}
-- On CPUs with performance and efficiency cores, only on the performance ones, as a run would take a lot longer on
-- the others.
local performance = io.open("/sys/devices/cpu_core/cpus")
if performance and vim.fn.executable("taskset") == 1 then
    machine.pinned = vim.trim(performance:read("a"))
end
if performance then
    performance:close()
end
-- Results are kept and compared by the hardware they ran on.
local machine_dir = (machine.cpu .. " " .. machine.cores):lower():gsub("[^%w]+", "-"):gsub("^%-", ""):gsub("%-$", "")

-- The benchmarks of the plugin in a new process, of the plugin at root when given, by name.
local function run(plugin, root)
    local out = vim.fn.tempname()
    local command = { vim.v.progpath, "--clean", "--headless", "-c", "luafile tests/bench.lua", "-c", "cq" }
    if machine.pinned then
        command = vim.list_extend({ "taskset", "-c", machine.pinned }, command)
    end
    local result = vim.system(command, {
        cwd = plugins_dir .. "/" .. plugin,
        env = { BENCH_OUT = out, PLUGIN_ROOT = root },
        text = true,
    }):wait()
    assert(result.code == 0, plugin .. " benchmarks failed:\n" .. result.stdout .. result.stderr)
    local file = assert(io.open(out))
    local results = vim.json.decode(file:read("a"))
    file:close()
    os.remove(out)
    return results
end

-- The median of each run and the fastest of all, by benchmark.
local function add(into, results)
    for name, result in pairs(results) do
        into[name] = into[name] or { unit = result.unit, order = result.order, medians = {}, min = math.huge }
        table.insert(into[name].medians, math.floor(result.median * 1e4 + 0.5) / 1e4)
        into[name].min = math.min(into[name].min, math.floor(result.min * 1e4 + 0.5) / 1e4)
    end
end

-- The results saved on this machine, the latest last, each with its name.
local function saved(plugin)
    local files = vim.fn.glob(("%s/%s/tests/results/%s/*.json"):format(plugins_dir, plugin, machine_dir), false, true)
    table.sort(files)
    return vim.tbl_map(function(path)
        local file = assert(io.open(path))
        local results = vim.json.decode(file:read("a"))
        file:close()
        results.name = vim.fn.fnamemodify(path, ":t:r")
        return results
    end, files)
end

-- The median of every benchmark in each of the latest saved results, by date and commit.
local function history(plugin)
    local all = vim.list_slice(saved(plugin), math.max(#saved(plugin) - 5, 1))
    io.stdout:write(("\n%s\n%-18s"):format(plugin, ""))
    for _, results in ipairs(all) do
        io.stdout:write(("%22s"):format(results.name:match("^%d+%-(%d+%-%d+)T") .. " " .. results.commit .. (results.dirty and "*" or "")))
    end
    io.stdout:write("\n")
    local latest = all[#all] and all[#all].benchmarks or {}
    local names = vim.tbl_keys(latest)
    table.sort(names, function(a, b)
        return latest[a].order < latest[b].order
    end)
    for _, name in ipairs(names) do
        io.stdout:write(("%-18s"):format(name))
        for _, results in ipairs(all) do
            local benchmark = results.benchmarks[name]
            io.stdout:write(benchmark and ("%19.2f %-2s"):format(stats.median(benchmark.medians), benchmark.unit) or ("%22s"):format("-"))
        end
        io.stdout:write("\n")
    end
end

local function save(plugin, benchmarks)
    local commit = git("rev-parse", "--short", "HEAD")
    local dirty = git("status", "--porcelain", "--", plugin, "shared.nvim") ~= ""
    local dir = ("%s/%s/tests/results/%s"):format(plugins_dir, plugin, machine_dir)
    vim.fn.mkdir(dir, "p")
    local path = ("%s/%s-%s%s.json"):format(dir, os.date("%Y-%m-%dT%H%M%S"), commit, dirty and "-dirty" or "")
    local data = { commit = commit, dirty = dirty, date = os.date("%Y-%m-%dT%H:%M:%S"), machine = machine, runs = options.runs, benchmarks = benchmarks }
    local file = assert(io.open(path, "w"))
    file:write(vim.json.encode(data, { indent = "  ", sort_keys = true }) .. "\n")
    file:close()
    return path
end

local function report(plugin, current, base, against)
    io.stdout:write(("\n%s, %d runs against %s\n"):format(plugin, options.runs, against))
    io.stdout:write(("%-18s %10s %7s %10s %8s %8s\n"):format("", "median", "spread", "base", "change", "p"))
    local names = vim.tbl_keys(current)
    table.sort(names, function(a, b)
        return current[a].order < current[b].order
    end)
    -- Compared together but for calibrate, which is about the machine.
    local compared, ps = {}, {}
    for _, name in ipairs(names) do
        if base and base[name] and name ~= "calibrate" then
            compared[name] = stats.compare(base[name].medians, current[name].medians)
            table.insert(ps, compared[name].p)
        end
    end
    local adjusted = stats.holm(ps)
    -- The smallest p-value the runs can give, apart as far as they can be, adjusted like the largest.
    local fewest = vim.fn["range"](1, options.runs)
    if #ps > 0 and stats.mann_whitney(fewest, vim.tbl_map(function(x)
        return x + options.runs
    end, fewest)) * #ps >= 0.05 then
        io.stdout:write(("Too few runs for %d benchmarks to ever differ significantly, take more with --runs.\n"):format(#ps))
    end
    for _, name in ipairs(names) do
        local now = current[name]
        local line = ("%-18s %7.2f %-2s %6.1f%%"):format(name, stats.median(now.medians), now.unit, stats.spread(now.medians) * 100)
        if compared[name] then
            compared[name].p = table.remove(adjusted, 1)
            local verdict = stats.verdict(compared[name])
            local change = (compared[name].ratio - 1) * 100
            line = line .. ("%10.2f %+7.1f%% %8.4f  %s"):format(stats.median(base[name].medians), change, compared[name].p, verdict ~= "same" and verdict or "")
        end
        io.stdout:write(line .. "\n")
    end
    local calibration = base and base.calibrate and stats.compare(base.calibrate.medians, current.calibrate.medians)
    if calibration and stats.verdict(calibration, 0.05) ~= "same" then
        io.stdout:write(("Calibration is %+.1f%%: the machine is not as it was, so the changes may not be the code's.\n"):format((calibration.ratio - 1) * 100))
    end
end

if options.history then
    for _, plugin in ipairs(options.plugins) do
        history(plugin)
    end
    return
end

-- Runs one process at a time, in turn with the base so both see the machine the same.
local worktree = options.base and vim.fn.tempname()
if worktree then
    git("worktree", "add", "--quiet", "--detach", worktree, options.base)
end
local ok, err = pcall(function()
    for _, plugin in ipairs(options.plugins) do
        local current, base = {}, worktree and {} or nil
        for r = 1, options.runs do
            io.stderr:write(("\r\27[K%s %d/%d"):format(plugin, r, options.runs))
            local base_root = worktree and ("%s/plugins/%s"):format(worktree, plugin)
            if base_root and r % 2 == 0 then
                add(base, run(plugin, base_root))
            end
            add(current, run(plugin))
            if base_root and r % 2 == 1 then
                add(base, run(plugin, base_root))
            end
        end
        io.stderr:write("\r\27[K")
        local against = options.base
        if not base then
            local all = saved(plugin)
            local results = all[#all]
            base, against = results and results.benchmarks, results and results.name or "nothing saved on this machine"
            if results and filter then
                against = against .. ", filtered, so in another state than when saved"
            end
            -- Anything else about how they ran that differs, which can make a difference of its own.
            for _, key in ipairs({ "nvim", "os", "pinned" }) do
                if results and results.machine[key] ~= machine[key] then
                    against = ("%s, %s was %s"):format(against, key, results.machine[key] or "not set")
                end
            end
        end
        report(plugin, current, base, against)
        if options.save then
            io.stdout:write("Saved " .. vim.fn.fnamemodify(save(plugin, current), ":~:.") .. "\n")
        end
    end
end)
if worktree then
    git("worktree", "remove", "--force", worktree)
end
assert(ok, err)
