local U = require("alex.utils")

-- TODO: This should only run for the oil filetype.
vim.on_key(function(key, typed)
    if U.current_buffer_filetype() ~= "oil" then
        return
    end
    if (typed == "-") or (key:len() == 3) then
        require("alex.native.winbar").set_winbar()
    end
end)
