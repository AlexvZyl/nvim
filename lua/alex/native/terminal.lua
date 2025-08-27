vim.api.nvim_create_autocmd("TermOpen", {
    callback = function()
        require("alex.native.statuscolumn").terminal()
    end,
})

vim.api.nvim_create_autocmd({ "TermOpen", "WinEnter" }, {
    pattern = "term://*",
    command = "startinsert",
})

-- Close the buffer when the terminal exits.
vim.api.nvim_create_autocmd({ "TermClose" }, {
    pattern = "term://*",
    command = "bd"
})

vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")

vim.opt.shell = "fish"
