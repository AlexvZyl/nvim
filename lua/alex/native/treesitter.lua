local M = {}

M.ignore_filetypes = {
    "lazy",
    "lazy_backdrop",
    "noice",
    "notify",
    "oil",
    "TelescopePrompt",
    "TelescopeResults",
    "no-neck-pain",
    "cmp_menu",
    "cmp_docs",
    "oil_preview",
}

function M.setup()
    local parsers = vim.fn.glob("/nix/store/*-nvim-treesitter-grammars/parser", true, true)
    for _, path in ipairs(parsers) do
        vim.opt.runtimepath:prepend(vim.fn.fnamemodify(path, ":h"))
    end

    vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
            if vim.tbl_contains(M.ignore_filetypes, ev.match) then
                return
            end
            local ok = pcall(vim.treesitter.start)
            if not ok then
                vim.notify("No treesitter parser for filetype: " .. ev.match, vim.log.levels.WARN)
            end
        end,
    })
end

M.setup()

return M
