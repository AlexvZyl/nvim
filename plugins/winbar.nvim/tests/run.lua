-- nvim --clean --headless -c "luafile tests/run.lua", with FILTER=text to run the tests with it in their name.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(root .. "/../shared.nvim")
package.path = root .. "/?.lua;" .. package.path
-- Not installed in CI.
package.preload["nvim-web-devicons"] = function()
    return {
        get_icon_by_filetype = function(filetype)
            return filetype ~= "" and "<" .. filetype .. ">" or nil
        end,
    }
end
vim.o.report, vim.o.showmode = 10000, false
require("winbar").setup({ exclude = { "excluded" } })

require("shared.test").run(root)
