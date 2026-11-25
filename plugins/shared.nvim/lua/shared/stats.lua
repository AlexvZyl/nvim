-- Statistics of benchmark timings, which are skewed by the odd slow run, so compared by rank rather than by mean.
local M = {}

-- Linear between the two closest values, q from 0 to 1.
function M.quantile(values, q)
    local sorted = vim.deepcopy(values)
    table.sort(sorted)
    local position = 1 + (#sorted - 1) * q
    local below = math.floor(position)
    local above = math.min(below + 1, #sorted)
    return sorted[below] + (sorted[above] - sorted[below]) * (position - below)
end

function M.median(values)
    return M.quantile(values, 0.5)
end

-- The interquartile range relative to the median, how much runs differ from each other.
function M.spread(values)
    return (M.quantile(values, 0.75) - M.quantile(values, 0.25)) / M.median(values)
end

-- Standard normal cumulative distribution, by Abramowitz and Stegun 7.1.26, within 1.5e-7.
local function normal_cdf(z)
    local x = math.abs(z) / math.sqrt(2)
    local t = 1 / (1 + 0.3275911 * x)
    local erf = 1 - t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429)))) * math.exp(-x * x)
    return z >= 0 and (1 + erf) / 2 or (1 - erf) / 2
end

-- How many of the orderings of m values among n others give each U, from 0 to m * n.
local counts = {}
local function u_counts(m, n)
    local key = m .. "," .. n
    if counts[key] then
        return counts[key]
    end
    local result = {}
    if m == 0 or n == 0 then
        result[0] = 1
    else
        -- The largest value is one of the m, above all n others, or one of the n.
        local largest_m, largest_n = u_counts(m - 1, n), u_counts(m, n - 1)
        for u = 0, m * n do
            result[u] = (largest_m[u - n] or 0) + (largest_n[u] or 0)
        end
    end
    counts[key] = result
    return result
end

-- Two-sided p-value of the Mann-Whitney U test, how likely samples this far apart are when both come from the same
-- distribution. Exact for small samples without ties, by the normal approximation otherwise.
function M.mann_whitney(a, b)
    local all = {}
    for _, value in ipairs(a) do
        table.insert(all, { value = value, first = true })
    end
    for _, value in ipairs(b) do
        table.insert(all, { value = value })
    end
    table.sort(all, function(x, y)
        return x.value < y.value
    end)
    -- Tied values share the mean of their ranks.
    local rank_sum, ties, i = 0, 0, 1
    while i <= #all do
        local j = i
        while j < #all and all[j + 1].value == all[i].value do
            j = j + 1
        end
        for k = i, j do
            rank_sum = rank_sum + (all[k].first and (i + j) / 2 or 0)
        end
        ties = ties + (j - i + 1) ^ 3 - (j - i + 1)
        i = j + 1
    end
    local m, n = #a, #b
    local u = rank_sum - m * (m + 1) / 2
    u = math.min(u, m * n - u)
    if ties == 0 and m * n <= 400 then
        local ways, total = u_counts(m, n), 0
        local at_most = 0
        for k = 0, m * n do
            total = total + ways[k]
            at_most = at_most + (k <= u and ways[k] or 0)
        end
        return math.min(2 * at_most / total, 1)
    end
    local sigma = math.sqrt(m * n / 12 * ((m + n + 1) - ties / ((m + n) * (m + n - 1))))
    if sigma == 0 then
        return 1
    end
    return math.min(2 * normal_cdf((u - m * n / 2 + 0.5) / sigma), 1)
end

-- The p-values by Holm-Bonferroni, so of many tests together one is only significant by chance 5% of the time.
function M.holm(ps)
    local order = {}
    for i in ipairs(ps) do
        order[i] = i
    end
    table.sort(order, function(a, b)
        return ps[a] < ps[b]
    end)
    local adjusted, largest = {}, 0
    for rank, i in ipairs(order) do
        largest = math.max(largest, math.min(ps[i] * (#ps - rank + 1), 1))
        adjusted[i] = largest
    end
    return adjusted
end

-- How the current timings compare to the base: the ratio of their medians and the p-value of the difference.
function M.compare(base, current)
    return { ratio = M.median(current) / M.median(base), p = M.mann_whitney(base, current) }
end

-- Significant at 5% and by more than the threshold, as a smaller change is not worth telling apart from noise.
function M.verdict(compared, threshold)
    if compared.p >= 0.05 or math.abs(compared.ratio - 1) <= (threshold or 0.02) then
        return "same"
    end
    return compared.ratio < 1 and "faster" or "slower"
end

return M
