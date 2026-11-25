local parts = require("statusline.parts")
local statusline = require("statusline")

local T = {}

-- Types the keys in the main loop and waits until they ran.
local function press(keys)
    local co = coroutine.running()
    vim.api.nvim_input(keys)
    vim.defer_fn(function()
        coroutine.resume(co)
    end, 50)
    coroutine.yield()
end

-- Replaces a function of a table for the test, putting it back after fn.
local function with(object, key, value, fn)
    local original = object[key]
    object[key] = value
    local ok, err = pcall(fn)
    object[key] = original
    assert(ok, err)
end

function T.setup_sets_one_global_statusline()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "text" })
    assert(vim.o.laststatus == 3, vim.o.laststatus)
    local drawn = vim.api.nvim_eval_statusline(vim.o.statusline, {}).str
    assert(drawn:find("NORMAL", 1, true) and drawn:find("1:1", 1, true), drawn)
end

function T.the_mode_shows_with_its_highlight()
    local normal = statusline.render()
    press("i<Cmd>lua _G.statusline_test = require('statusline').render()<CR><Esc>")
    local insert = _G.statusline_test
    _G.statusline_test = nil
    assert(normal:find("%#StatuslineModeNormal# ", 1, true) and normal:find("NORMAL", 1, true), normal)
    assert(insert:find("%#StatuslineModeInsert# ", 1, true) and insert:find("INSERT", 1, true), insert)
end

-- Like operator pending, by the mode they are in.
function T.submodes_show_as_their_mode()
    with(vim.api, "nvim_get_mode", function()
        return { mode = "niI" }
    end, function()
        local drawn = statusline.render()
        assert(drawn:find("NORMAL", 1, true), drawn)
    end)
end

function T.toggles_are_highlighted_by_whether_they_are_enabled()
    local toggles = parts.toggles()
    assert(toggles == "%#StatuslineOn#on%*%#StatuslineOff#off%*", toggles)
end

function T.diagnostics_are_counted_by_severity()
    local ns = vim.api.nvim_create_namespace("statusline_test")
    local severity = vim.diagnostic.severity
    local function diagnostic(level)
        return { lnum = 0, col = 0, message = "x", severity = level }
    end
    local empty = parts.diagnostics()
    vim.diagnostic.set(ns, 0, { diagnostic(severity.ERROR), diagnostic(severity.ERROR), diagnostic(severity.HINT) })
    local letters = parts.diagnostics()
    vim.diagnostic.config({ signs = { text = { [severity.ERROR] = "!" } } })
    local signs = parts.diagnostics()
    vim.diagnostic.config({ signs = true })
    vim.diagnostic.reset(ns)
    assert(empty == "", empty)
    assert(letters == "  %#StatuslineDiagError#E 2%* %#StatuslineDiagHint#H 1%*", letters)
    assert(signs == "  %#StatuslineDiagError#! 2%* %#StatuslineDiagHint#H 1%*", signs)
end

-- Clients by name, efm by the linters it runs for the filetype, and prompts keep the clients of the buffer before.
function T.lsp_clients_show_by_name()
    local efm = { name = "efm", config = { settings = { languages = { lua = { { lintSource = "luacheck" }, {} } } } } }
    local shown = {}
    with(vim.lsp, "get_clients", function(_)
        return { { name = "lua_ls" }, efm }
    end, function()
        vim.bo.filetype = "lua"
        shown.lua = parts.lsp_clients()
        vim.bo.filetype = "python"
        shown.python = parts.lsp_clients()
    end)
    with(vim.lsp, "get_clients", function(_)
        return {}
    end, function()
        vim.bo.filetype = "TelescopePrompt"
        shown.prompt = parts.lsp_clients()
        vim.bo.filetype = "text"
        shown.none = parts.lsp_clients()
    end)
    vim.bo.filetype = ""
    assert(shown.lua:find("[lua_ls•luacheck]", 1, true), shown.lua)
    assert(shown.python:find("[lua_ls•efm]", 1, true), shown.python)
    assert(shown.prompt == shown.python, shown.prompt)
    assert(shown.none:find("[]", 1, true), shown.none)
end

function T.an_unknown_mode_shows_once_as_an_error()
    local messages = {}
    with(vim.api, "nvim_get_mode", function()
        return { mode = "?" }
    end, function()
        with(vim, "notify", function(message)
            table.insert(messages, message)
        end, function()
            local drawn = statusline.render()
            press("<Ignore>")
            assert(drawn:find("??????", 1, true) and drawn:find("StatuslineModeUnknown", 1, true), drawn)
        end)
    end)
    assert(#messages == 1 and messages[1]:find("?", 1, true), vim.inspect(messages))
end

-- Colorschemes clear the highlights, which Neovim links back to their defaults as they are set as defaults.
function T.highlights_come_back_after_a_colorscheme()
    vim.cmd("highlight clear")
    vim.cmd.doautocmd("ColorScheme")
    local hl = vim.api.nvim_get_hl(0, { name = "StatuslineModeNormal" })
    assert(hl.link == "PmenuSel", vim.inspect(hl))
end

return T
