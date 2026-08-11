local function startup_dir()
    local argv = vim.fn.argv()
    if #argv ~= 1 then
        return nil
    end

    local path = vim.fn.expand(argv[1])
    if vim.fn.isdirectory(path) == 0 then
        return nil
    end

    return vim.fn.fnamemodify(path, ":p")
end

local dir = startup_dir()
if dir ~= nil then
    vim.api.nvim_set_current_dir(dir)
end
