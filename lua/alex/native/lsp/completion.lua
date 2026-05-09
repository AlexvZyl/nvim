local chars = require("alex.utils.chars")

vim.opt.autocomplete = true
vim.opt.pumheight = 10
vim.opt.completeopt = { "menuone", "fuzzy", "popup", "noselect" }
vim.opt.pumborder = "rounded"
vim.opt.complete = "o"

local ABBR_MIN_WIDTH = 50
local ABBR_MAX_WIDTH = 25
local MENU_MAX_WIDTH = 50

local kind_names = vim.lsp.protocol.CompletionItemKind
local kind_icons = chars.kind_icons
local unknown_icon = kind_icons.Unknown
local pad = string.rep(" ", ABBR_MIN_WIDTH)

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client == nil then
            vim.schedule(function()
                vim.notify("LspAttach called without client", vim.log.levels.WARN)
            end)
            return
        end

        -- TODO: Not sure why this has to be in the callback.
        vim.keymap.set("i", "<C-Space>", vim.lsp.completion.get)
        vim.keymap.set("i", "<CR>", function()
            return vim.fn.pumvisible() == 1 and "<C-y>" or "<CR>"
        end, { buffer = ev.buf, expr = true })

        assert(client)
        if client:supports_method("textDocument/completion") then
            vim.lsp.completion.enable(true, client.id, ev.buf, {
                autotrigger = true,
                -- Formatting.
                convert = function(item)
                    local abbr = item.label
                    abbr = abbr:gsub("%b()", ""):gsub("%b{}", "")
                    abbr = abbr:match("[%w_.]+.*") or abbr
                    abbr = #abbr > ABBR_MAX_WIDTH and abbr:sub(1, ABBR_MAX_WIDTH - 1) .. "…"
                        or abbr
                    abbr = #abbr < ABBR_MIN_WIDTH and abbr .. pad:sub(1, ABBR_MIN_WIDTH - #abbr)
                        or abbr

                    local menu = item.detail or ""
                    menu = #menu > MENU_MAX_WIDTH and menu:sub(1, MENU_MAX_WIDTH - 1) .. "…"
                        or menu

                    local kind = kind_icons[kind_names[item.kind]] or unknown_icon

                    return { abbr = abbr, menu = menu, kind = kind }
                end,
            })
        else
            vim.schedule(function()
                vim.notify("LSP does not support auto complete", vim.log.levels.WARN)
            end)
        end
    end,
})

-- VIBE CODED SHUOLD PROBABLY BE REMOVED.
-- Adds borders to hover doc.

local orig_open_floating_preview = vim.lsp.util.open_floating_preview

vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
    opts = opts or {}
    opts.border = opts.border or "rounded"
    return orig_open_floating_preview(contents, syntax, opts, ...)
end

local function set_popup_border(winid)
    if winid and winid >= 0 and vim.api.nvim_win_is_valid(winid) then
        pcall(vim.api.nvim_win_set_config, winid, { border = "rounded" })
    end
end

vim.api.nvim_create_autocmd("CompleteChanged", {
    group = vim.api.nvim_create_augroup("CompletionPopupBorder", { clear = true }),
    callback = function()
        vim.schedule(function()
            set_popup_border(vim.fn.complete_info({ "preview_winid" }).preview_winid)
        end)
    end,
})

if vim.api.nvim__complete_set then
    local orig = vim.api.nvim__complete_set
    vim.api.nvim__complete_set = function(index, opts)
        local windata = orig(index, opts)
        set_popup_border(windata and windata.winid)
        return windata
    end
end
