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

function M.file_exists(file)
    local f = io.open(file, "r")
    if f then
        io.close(f)
        return true
    else
        return false
    end
end

function M.in_home_dir(subdir)
    local cwd = vim.loop.cwd()
    local path = vim.loop.os_homedir()
    if subdir ~= nil then
        path = path .. "/" .. subdir
    end

    return string.sub(cwd, 1, #path) == path
end

return M
