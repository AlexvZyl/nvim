-- nvim -l plugins/shared.nvim/bench.lua [--runs N] [--base REV] [plugin.nvim ...]
--
-- Benchmarks the plugins, all by default, as they are on disk against the base revision (main by default), and
-- writes the comparison as JSON to data/bench/ at the repo root. A commit's results are kept there by its hash, so a
-- commit benchmarked before on this machine is not run again. Uncommitted changes are always run.
-- Medians of the runs are compared by the Mann-Whitney U test, adjusted for testing every benchmark at once, which
-- takes 10 runs or so to show anything. The calibrate benchmark does the same work every time, so a change in it is
-- the machine, not the code.
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
-- Only some benchmarks run, in another state than all of them, so their results are not kept.
local filter = os.getenv("FILTER")

local function git(...)
    local result = vim.system({ "git", "-C", plugins_dir, ... }, { text = true }):wait()
    assert(result.code == 0, table.concat({ "git", ... }, " ") .. ": " .. result.stderr)
    return vim.trim(result.stdout)
end

local repo_root = git("rev-parse", "--show-toplevel")
local data_dir = repo_root .. "/data/bench"

local cpus = vim.uv.cpu_info()
local machine = { cpu = vim.trim(cpus[1].model), cores = #cpus, nvim = tostring(vim.version()) }
-- On CPUs with performance and efficiency cores, only the performance ones, as runs take longer on the others.
local performance = io.open("/sys/devices/cpu_core/cpus")
if performance then
    machine.pinned = vim.fn.executable("taskset") == 1 and vim.trim(performance:read("a")) or nil
    performance:close()
end

local function read_json(path)
    local file = io.open(path)
    if not file then
        return nil
    end
    local decoded = vim.json.decode(file:read("a"))
    file:close()
    return decoded
end

local function write_json(path, data)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    local file = assert(io.open(path, "w"))
    file:write(vim.json.encode(data, { indent = "  ", sort_keys = true }) .. "\n")
    file:close()
end

local function results_path(plugin, hash)
    return ("%s/%s/%s.json"):format(data_dir, plugin, hash)
end

-- A commit's kept results, when from this machine with as many runs.
local function kept(plugin, hash)
    local kept_results = not filter and hash and read_json(results_path(plugin, hash))
    if kept_results and vim.deep_equal(kept_results.machine, machine) and kept_results.runs >= options.runs then
        return kept_results.benchmarks
    end
end

-- The benchmarks in the plugin directory, by name, in a new process.
local function run(plugin_dir)
    local out = vim.fn.tempname()
    local command = { vim.v.progpath, "--clean", "--headless", "-c", "luafile tests/bench.lua", "-c", "cq" }
    if machine.pinned then
        command = vim.list_extend({ "taskset", "-c", machine.pinned }, command)
    end
    local result = vim.system(command, { cwd = plugin_dir, env = { BENCH_OUT = out }, text = true }):wait()
    assert(result.code == 0, plugin_dir .. " benchmarks failed:\n" .. result.stdout .. result.stderr)
    local results = assert(read_json(out))
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

-- Each benchmark of the current side against the base, in the order they ran.
local function compare(current, base)
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
    local benchmarks = {}
    for _, name in ipairs(names) do
        local now = current[name]
        local entry = { name = name, unit = now.unit, median = stats.median(now.medians), spread = stats.spread(now.medians) }
        if compared[name] then
            compared[name].p = table.remove(adjusted, 1)
            entry.base_median = stats.median(base[name].medians)
            entry.change = compared[name].ratio - 1
            entry.p = compared[name].p
            entry.verdict = stats.verdict(compared[name])
        elseif not base[name] then
            entry.verdict = "new"
        end
        table.insert(benchmarks, entry)
    end
    local removed = {}
    for name in pairs(base) do
        if not current[name] then
            table.insert(removed, name)
        end
    end
    table.sort(removed)
    -- The smallest p-value the runs can give, adjusted like the largest.
    local fewest = vim.fn.range(1, options.runs)
    local farthest_apart = vim.tbl_map(function(x)
        return x + options.runs
    end, fewest)
    local calibration = base.calibrate and current.calibrate and stats.compare(base.calibrate.medians, current.calibrate.medians)
    return {
        benchmarks = benchmarks,
        removed = removed,
        too_few_runs = #ps > 0 and stats.mann_whitney(fewest, farthest_apart) * #ps >= 0.05,
        calibration_change = calibration and calibration.ratio - 1,
        machine_changed = calibration and stats.verdict(calibration, 0.05) ~= "same",
    }
end

local head = git("rev-parse", "HEAD")
local base_hash = git("rev-parse", options.base .. "^{commit}")
local comparison = {
    date = os.date("%Y-%m-%dT%H:%M:%S"),
    machine = machine,
    runs = options.runs,
    filter = filter,
    base = { revision = options.base, hash = base_hash },
    current = { head = head },
    plugins = {},
}

local worktree
local ok, err = pcall(function()
    for _, plugin in ipairs(options.plugins) do
        local current_dir = plugins_dir .. "/" .. plugin
        -- Uncommitted changes to the plugin or what it shares have no hash to keep results by.
        local dirty = git("status", "--porcelain", "--", current_dir, shared) ~= ""
        local current_hash = not dirty and head or nil
        local current, base = kept(plugin, current_hash), kept(plugin, base_hash)
        local base_dir
        if not base then
            if not worktree then
                worktree = vim.fn.tempname()
                git("worktree", "add", "--quiet", "--detach", worktree, base_hash)
            end
            base_dir = worktree .. "/" .. vim.fs.relpath(repo_root, current_dir)
        end
        if base_dir and not vim.uv.fs_stat(base_dir .. "/tests/bench.lua") then
            comparison.plugins[plugin] = { error = "no benchmarks at " .. options.base }
        else
            local runs = { current = not current and {} or nil, base = not base and {} or nil }
            for r = 1, (runs.current or runs.base) and options.runs or 0 do
                io.stderr:write(("\r\27[K%s %d/%d"):format(plugin, r, options.runs))
                -- Alternates which goes first, when both run.
                if runs.base and r % 2 == 0 then
                    add(runs.base, run(base_dir))
                end
                if runs.current then
                    add(runs.current, run(current_dir))
                end
                if runs.base and r % 2 == 1 then
                    add(runs.base, run(base_dir))
                end
            end
            io.stderr:write("\r\27[K")
            for side, hash in pairs({ current = current_hash, base = base_hash }) do
                if runs[side] and hash and not filter then
                    write_json(results_path(plugin, hash), { hash = hash, machine = machine, runs = options.runs, benchmarks = runs[side] })
                end
            end
            current, base = current or runs.current, base or runs.base
            comparison.plugins[plugin] = compare(current, base)
            comparison.plugins[plugin].dirty = dirty
            comparison.plugins[plugin].reused = { current = runs.current == nil, base = runs.base == nil }
        end
    end
end)
if worktree then
    git("worktree", "remove", "--force", worktree)
end
assert(ok, err)

local path = ("%s/%s-%s-vs-%s.json"):format(data_dir, os.date("%Y-%m-%dT%H%M%S"), head:sub(1, 7), base_hash:sub(1, 7))
write_json(path, comparison)
io.stdout:write(path .. "\n")
