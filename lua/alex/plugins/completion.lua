local CMP = require("cmp")
local U = require("alex.utils")

require("alex.plugins.nvim-cmp")
require("luasnip.loaders.from_vscode").lazy_load()

-- Main.
local sources = CMP.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "path" },
})
local snippet = {
    expand = function(args)
        require("luasnip").lsp_expand(args.body)
    end,
}
CMP.setup({
    sources = sources,
    snippet = snippet,
})

-- Cmdline.
local cmdline_window = {
    completion = {
        winhighlight = "Normal:WhichKeyNormal,Search:None",
        scrollbar = false,
        border = "none",
        col_offset = -2,
        side_padding = 0,
    },
}
local cmdline = {
    window = cmdline_window,
    completion = { autocomplete = false },
    mapping = CMP.mapping.preset.cmdline(),
    sources = CMP.config.sources({
        { name = "cmdline" },
        { name = "path" },
    }),
}
CMP.setup.cmdline({ ":", ":!" }, cmdline)

-- Search.
local search = {
    window = cmdline_window,
    mapping = CMP.mapping.preset.cmdline(),
    sources = CMP.config.sources({ { name = "buffer" } }),
}
CMP.setup.cmdline({ "/", "?" }, search)

require("alex.keymaps").completion()
