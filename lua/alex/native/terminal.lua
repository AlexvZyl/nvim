local M = {}

function M.setup()
    vim.api.nvim_create_autocmd("TermOpen", {
        callback = function()
            require("alex.native.statuscolumn").terminal()
        end,
    })

    vim.api.nvim_create_autocmd({ "TermOpen", "WinEnter" }, {
        pattern = "term://*",
        callback = function()
            if vim.bo[vim.api.nvim_get_current_buf()].filetype == "godot" then
                return
            end
            vim.cmd("startinsert")
        end
    })

    -- Close the buffer when the terminal exits.
    vim.api.nvim_create_autocmd({ "TermClose" }, {
        pattern = "term://*",
        callback = function(ev)
            if not vim.api.nvim_buf_is_valid(ev.buf) then
                return
            end
            if vim.bo[ev.buf].filetype == "godot" then
                return
            end
            vim.cmd("bd " .. ev.buf)
        end,
    })

    vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")
end

M.setup()

return M
