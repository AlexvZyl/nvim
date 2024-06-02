local M = {}

function M.merge(table1, table2)
    if table1 == table2 == nil then return {} end
    if table1 == nil then
        return table2
    elseif table2 == nil then
        return table1
    end
    return vim.tbl_deep_extend("force", table1, table2)
end

function M.length(table)
    local count = 0
    for _, _ in ipairs(table) do
        count = count + 1
    end
    return count
end

return M
