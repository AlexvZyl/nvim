local chars = require("alex.utils.chars")

vim.opt.autocomplete = false
vim.opt.pumheight = 10
vim.opt.completeopt = { "menuone", "fuzzy", "popup", "noselect" }
vim.opt.pumborder = "rounded"
vim.opt.complete = "o"
vim.opt.previewpopup = {
    border = "rounded",
    height = nil,
    width = nil
}

local ABBR_MIN_WIDTH = 50
local ABBR_MAX_WIDTH = 25
local MENU_MAX_WIDTH = 50

local kind_names = vim.lsp.protocol.CompletionItemKind
local kind_icons = chars.kind_icons
local unknown_icon = kind_icons.Unknown
local pad = string.rep(" ", ABBR_MIN_WIDTH)

local kind_hl = {
    Text = "@string",
    Method = "@function.method",
    Function = "@function",
    Constructor = "@constructor",
    Field = "@variable.member",
    Variable = "@variable",
    Class = "@type",
    Interface = "@type",
    Module = "@module",
    Property = "@property",
    Unit = "@number",
    Value = "@constant",
    Enum = "@type",
    Keyword = "@keyword",
    Snippet = "@string.special",
    Color = "@constant",
    File = "@string.special.path",
    Reference = "@variable",
    Folder = "@string.special.path",
    EnumMember = "@constant",
    Constant = "@constant",
    Struct = "@type",
    Event = "@function",
    Operator = "@operator",
    TypeParameter = "@type.definition",
}

local function format_item(item)
    local abbr = item.label
    abbr = abbr:gsub("%b()", ""):gsub("%b{}", "")
    abbr = abbr:match("[%w_.]+.*") or abbr
    abbr = #abbr > ABBR_MAX_WIDTH and abbr:sub(1, ABBR_MAX_WIDTH - 1) .. "…" or abbr
    abbr = #abbr < ABBR_MIN_WIDTH and abbr .. pad:sub(1, ABBR_MIN_WIDTH - #abbr) or abbr

    local menu = item.detail or ""
    menu = #menu > MENU_MAX_WIDTH and menu:sub(1, MENU_MAX_WIDTH - 1) .. "…" or menu

    local kind_name = kind_names[item.kind] or "Unknown"
    local kind = kind_icons[kind_name] or unknown_icon

    return {
        abbr = abbr,
        menu = menu,
        kind = kind,
        kind_hlgroup = kind_hl[kind_name],
    }
end

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client == nil then
            vim.schedule(function()
                vim.notify("LspAttach called without client", vim.log.levels.WARN)
            end)
            return
        end

        vim.keymap.set("i", "<C-Space>", vim.lsp.completion.get, { buffer = ev.buf })
        vim.keymap.set("i", "<CR>", function()
            return vim.fn.pumvisible() == 1 and "<C-y>" or "<CR>"
        end, { buffer = ev.buf, expr = true })

        assert(client)
        if client:supports_method("textDocument/completion") then
            vim.lsp.completion.enable(true, client.id, ev.buf, {
                autotrigger = false,
                convert = format_item,
            })
        elseif client.name ~= "efm" then
            vim.schedule(function()
                vim.notify("LSP does not support auto complete", vim.log.levels.WARN)
            end)
        end
    end,
})


-- AI SLOP.  But it works.
-- Remove when support is in natively.

-- The completion docs popup is a native info window not covered by 'previewpopup'.
-- Docs usually arrive async via completionItem/resolve, which creates the window
-- through nvim__complete_set; border it there so even the first window gets one.
local function border_info_win(winid)
    if winid and winid > 0 and vim.api.nvim_win_is_valid(winid) then
        pcall(vim.api.nvim_win_set_config, winid, { border = "rounded" })
    end
end
if vim.api.nvim__complete_set then
    local orig = vim.api.nvim__complete_set
    vim.api.nvim__complete_set = function(index, opts)
        local data = orig(index, opts)
        border_info_win(data and data.winid)
        return data
    end
end
vim.api.nvim_create_autocmd("CompleteChanged", {
    callback = function()
        vim.schedule(function()
            border_info_win(vim.fn.complete_info({ "selected" }).preview_winid)
        end)
    end,
})
