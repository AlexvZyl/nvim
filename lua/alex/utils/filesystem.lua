local M = {}

function M.file_exists(file)
    local f = io.open(file, 'r')
    if f then
        io.close(f)
        return true
    else
        return false
    end
end

return M
