local stats = require("shared.stats")

local T = {}

-- Against scipy.stats.mannwhitneyu.
local function close(actual, expected)
    assert(math.abs(actual - expected) < 1e-4, ("%s, expected %s"):format(actual, expected))
end

function T.quantiles_interpolate_between_values()
    assert(stats.median({ 3, 1, 2 }) == 2)
    assert(stats.median({ 4, 1, 3, 2 }) == 2.5)
    assert(stats.quantile({ 1, 2, 3, 4, 5 }, 0.25) == 2)
    assert(stats.spread({ 1, 2, 3, 4, 5 }) == 2 / 3)
end

function T.small_samples_without_ties_are_exact()
    close(stats.mann_whitney({ 1, 2, 3, 4, 5 }, { 6, 7, 8, 9, 10 }), 0.0079365)
    close(stats.mann_whitney({ 1, 3, 5, 7, 9, 11 }, { 2, 4, 6, 8, 10, 12, 14 }), 0.4452214)
end

function T.large_samples_are_approximated()
    local a, b = {}, {}
    for i = 1, 30 do
        a[i], b[i] = i, i + 10
    end
    close(stats.mann_whitney(a, b), 0.0002245)
end

function T.ties_are_corrected_for()
    close(stats.mann_whitney({ 1, 1, 2, 2, 3 }, { 2, 3, 3, 4, 4 }), 0.0524116)
    assert(stats.mann_whitney({ 1, 1, 1 }, { 1, 1, 1 }) == 1)
end

function T.changes_are_significant_beyond_noise_and_the_threshold()
    local base = { 10, 10.1, 9.9, 10.2, 9.8, 10, 10.1, 9.9 }
    local faster = vim.tbl_map(function(x)
        return x * 0.8
    end, base)
    local barely = vim.tbl_map(function(x)
        return x * 0.99
    end, base)
    local compared = stats.compare(base, faster)
    assert(stats.verdict(compared) == "faster" and math.abs(compared.ratio - 0.8) < 1e-9, vim.inspect(compared))
    assert(stats.verdict(stats.compare(faster, base)) == "slower")
    assert(stats.verdict(stats.compare(base, barely)) == "same")
    assert(stats.verdict(stats.compare(base, { 9, 11, 10.5, 9.5 })) == "same")
    assert(stats.verdict({ ratio = 0.9, p = 0.01 }, 0.15) == "same")
end

-- Sorted 0.005, 0.01, 0.03, 0.04 scale by 4, 3, 2, 1, never below the one before.
function T.holm_adjusts_by_rank_and_keeps_the_order()
    local adjusted = stats.holm({ 0.01, 0.04, 0.03, 0.005 })
    for i, expected in ipairs({ 0.03, 0.06, 0.06, 0.02 }) do
        close(adjusted[i], expected)
    end
end

return T
