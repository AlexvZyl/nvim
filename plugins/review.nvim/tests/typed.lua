-- Run by the tests in an nvim of its own, whose main loop redraws, scrolls and runs scheduled callbacks between
-- typed keys like it does for a person, which the tests run in one go do not. Prints, as JSON, how many redraws there
-- were and how many of them drew the deleted lines in a gutter other than the window's.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(root .. "/../shared.nvim")
package.path = root .. "/?.lua;" .. package.path
local h = require("tests.helpers")
require("review").setup({})

h.repo(h.lines(300), vim.list_slice(h.lines(300), 1, 250))
vim.o.lines, vim.o.columns = 50, 200
-- A statuscolumn with relative numbers, which measures narrower between an edit and the redraw.
vim.o.number, vim.o.relativenumber, vim.o.numberwidth, vim.o.signcolumn = true, true, 4, "yes"
vim.o.statuscolumn = "%#LineNr# %*%s%=%{v:relnum?v:relnum:v:lnum}%*  "
local main = h.review("file.txt")
local buf = vim.api.nvim_get_current_buf()

local namespace = vim.api.nvim_create_namespace("review_deleted")
local result = { redraws = 0, misdrawn = 0 }
vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace("review_typed"), {
    on_end = function()
        result.redraws = result.redraws + 1
        local width = vim.fn.getwininfo(main)[1].textoff
        for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })) do
            local chunks = mark[4].virt_lines[1]
            if vim.fn.strdisplaywidth(chunks[1][1] .. chunks[2][1]) ~= width then
                result.misdrawn = result.misdrawn + 1
                return
            end
        end
    end,
})

-- Deletes a line then repeats it, with all the keys typed ahead like a held key, then one at a time. Counted from
-- the first key, as before the window is drawn its gutter is not known.
local steps = {
    function()
        result.redraws, result.misdrawn = 0, 0
        vim.cmd("normal! 200Gzz")
        vim.api.nvim_input("dd" .. string.rep(".", 40))
    end,
    function()
        vim.cmd("normal! 150Gzz")
        local timer, count = vim.uv.new_timer(), 0
        timer:start(0, 15, function()
            count = count + 1
            vim.api.nvim_input(count == 1 and "dd" or ".")
            if count == 40 then
                timer:close()
            end
        end)
    end,
}
for i, step in ipairs(steps) do
    vim.defer_fn(step, 100 + (i - 1) * 1000)
end
vim.defer_fn(function()
    io.stdout:write(vim.json.encode(result))
    vim.cmd("qa!")
end, 100 + #steps * 1000)
