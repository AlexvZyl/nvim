-- I want to keep all of the key bindings in one file so that it is easy to see
-- what is being used and ensure nothing being overwritten by accident.

local U = require("alex.utils")

local n, i, v, t, c = "n", "i", "v", "t", "c"
local ex_t = { n, i, v }
local n_i = { n, i }
local n_v = { n, v }

local keymap = vim.keymap.set
local default_settings = { noremap = true, silent = true }
local allow_remap = { noremap = false, silent = true }
local default_expr = { noremap = true, expr = true }

local M = {}

function M.init()
    M.native()
    M.editing()
    M.lsp()

    -- Lazyload dependents:
    M.telescope()
    M.no_neck_pain()
end

function M.lsp()
    keymap(n, "RR", function()
        pcall(vim.lsp.buf.rename)
    end, default_settings)
    keymap(n, "gi", "<Cmd>Telescope lsp_implementations<CR>", default_settings)
    keymap(n, "gh", function()
        pcall(vim.lsp.buf.hover)
    end, default_settings)
    keymap(n_i, "<C-\\>", function()
        pcall(vim.lsp.buf.signature_help)
    end, default_settings)

    keymap(n, "ge", function()
        require("alex.native.lsp").open_diagnostics_float()
    end, default_settings)
    keymap(n, "[e", function()
        require("alex.native.lsp").prev_diag()
    end, default_settings)
    keymap(n, "]e", function()
        require("alex.native.lsp").next_diag()
    end, default_settings)
    keymap(n, "[E", function()
        require("alex.native.lsp").prev_error()
    end, default_settings)
    keymap(n, "]E", function()
        require("alex.native.lsp").next_error()
    end, default_settings)

    keymap(n, "<leader>l", "<Cmd>LspInfo<CR>", default_settings)
end

function M.blame()
    keymap(n, "<leader>b", "<Cmd>GitBlameToggle<CR>", default_settings)
end

function M.no_neck_pain()
    keymap(n, "<leader>n", require("alex.plugins.no-neck-pain").toggle, default_settings)
end

function M.noice()
    local duration = require("alex.plugins.neoscroll-nvim").scroll_duration

    keymap({ "n", "i", "s" }, "<C-d>", function()
        if not require("noice.lsp").scroll(4) then
            require("neoscroll").ctrl_d({ duration = duration })
        end
    end, { silent = true })

    keymap({ "n", "i", "s" }, "<C-u>", function()
        if not require("noice.lsp").scroll(-4) then
            return require("neoscroll").ctrl_u({ duration = duration })
        end
    end, { silent = true })

    keymap(n, "<C-m>", "<Cmd>NoiceDismiss<CR>", default_settings)
end

function M.native()
    -- Windows
    keymap(n, "<C-w><C-c>", "<Cmd>wincmd c<CR>", default_settings)
    keymap(n, "<C-h>", "<Cmd>wincmd h<CR>", default_settings)
    keymap(n, "<C-j>", "<Cmd>wincmd j<CR>", default_settings)
    keymap(n, "<C-k>", "<Cmd>wincmd k<CR>", default_settings)
    keymap(n, "<C-l>", "<Cmd>wincmd l<CR>", default_settings)
    keymap(t, "<C-w><C-c>", "<Cmd>wincmd c<CR>", default_settings)
    keymap(t, "<C-h>", "<C-\\><C-n><C-w>h", default_settings)
    keymap(t, "<C-j>", "<C-\\><C-n><C-w>j", default_settings)
    keymap(t, "<C-k>", "<C-\\><C-n><C-w>k", default_settings)
    keymap(t, "<C-l>", "<C-\\><C-n><C-w>l", default_settings)

    -- Misc
    keymap(n, "<Esc>", "<Cmd>noh<CR>", allow_remap)
    keymap(n_v, "<C-e>", "j<C-e>", default_settings)
    keymap(n_v, "<C-y>", "k<C-y>", default_settings)
    keymap(n, "K", "<nop>", default_settings)
    keymap(n, "<leader>d", function()
        require("alex.native.lsp").toggle_virtual_diagnostics()
    end, default_settings)
    keymap(n, "<leader>f", function()
        require("alex.native.lsp").toggle_format_enabled()
    end, default_settings)
    keymap(n, "gm", "<Cmd>vertical Man<CR>", default_settings)

    -- Buffers
    keymap(n, "Q", function()
        require("alex.keymaps.utils").delete_buffer()
    end, default_settings)

    keymap("n", "yp", '<Cmd>let @+ = expand("%")<CR>')
    keymap("n", "yP", '<Cmd>let @+ = expand("%:p")<CR>')

    -- Quickfix.
    keymap(n, "}", "<Cmd>cnext<CR>zz_", default_settings)
    keymap(n, "{", "<Cmd>cprevious<CR>zz_", default_settings)

    -- HACK: Don't copy selected region back into registers.
    vim.keymap.set(v, "p", '"_dP', default_settings)
    vim.keymap.set(v, "P", '"_dP', default_settings)

    -- Custom cmdline backspace behavior.
    vim.keymap.set("c", "<BS>", function()
        local cmd = vim.fn.getcmdline()

        -- Don't close on empty.
        if #cmd == 0 then
            return ""
        end

        -- Stay in modes.
        if cmd:match("^!$") or cmd:match("^lua $") or cmd:match("^h $") then
            return ""
        end

        return "<BS>"
    end, default_expr)
end

function M.oil()
    keymap(n, "<leader>e", function()
        require("alex.keymaps.utils").toggle_oil()
    end)
    require("oil").setup({
        keymaps = {
            ["<CR>"] = "actions.select",
            ["-"] = "actions.parent",
        },
        use_default_keymaps = false,
    })
end

function M.editing()
    keymap(i, "<Esc>", "<Esc>`^", default_settings)
    keymap(ex_t, "<C-s>", function()
        require("alex.keymaps.utils").save_file()
    end, default_settings)
    keymap(v, "i", "I", default_settings)
    keymap(n, "s", function()
        require("leap").leap({})
    end)
    keymap(n, "S", function()
        require("leap").leap({ backward = true })
    end)
    keymap(n, "<leader>v", function()
        require("alex.keymaps.utils").toggle_diffview()
    end)
end

function M.telescope()
    keymap(n, "fh", function()
        require("telescope.builtin").help_tags({})
    end)
    keymap(n, "z=", function()
        require("telescope.builtin").spell_suggest({})
    end)
    keymap(n, "fk", function()
        require("telescope.builtin").keymaps({})
    end)
    keymap(n, "fj", function()
        require("telescope.builtin").jumplist({ cwd = vim.loop.cwd() })
    end)
    keymap(n, "fm", function()
        require("telescope.builtin").man_pages({ sections = { "ALL" } })
    end)

    keymap(n, "fo", function()
        require("telescope.builtin").oldfiles({ cwd = vim.loop.cwd() })
    end, default_settings)
    keymap(n, "fO", function()
        require("telescope.builtin").oldfiles({ cwd = vim.fn.expand("~") })
    end, default_settings)
    keymap(n, "ff", function()
        require("telescope.builtin").find_files()
    end)
    keymap(n, "fF", function()
        require("telescope.builtin").find_files({ cwd = U.get_git_root() })
    end, default_settings)
    keymap(n, "fw", function()
        require("telescope.builtin").current_buffer_fuzzy_find({})
    end, default_settings)

    keymap(n, "fW", function()
        require("telescope.builtin").live_grep({ cwd = U.get_git_root() })
    end, default_settings)

    keymap(n, "<C-n>", "<Cmd>Telescope buffers previewer=false<CR>", default_settings)
    keymap(n, "fd", "<Cmd>Telescope diagnostics line_width=full bufnr=0<CR>", default_settings)
    keymap(n, "fD", "<Cmd>Telescope diagnostics line_width=full<CR>", default_settings)

    keymap(n_v, "fg", function()
        require("telescope.builtin").registers()
    end, default_settings)

    keymap(n, "ft", "<Cmd>TodoTelescope previewer=false wrap_results=false<CR>", default_settings)
    keymap(
        n,
        "fT",
        "<Cmd>TodoTelescope previewer=false wrap_results=false cwd=" .. U.get_git_root() .. "<CR>",
        default_settings
    )

    -- For LSP.
    keymap(n, "fs", "<Cmd>Telescope lsp_document_symbols<CR>", default_settings)
    -- TODO: I don't want this to jump if there is only one entry.
    keymap(n, "gr", "<Cmd>Telescope lsp_references<CR>", default_settings)
    keymap(n, "gd", "<Cmd>Telescope lsp_definitions<CR>", default_settings)
end

function M.leap()
    vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap-forward)")
    vim.keymap.set({ "n", "x", "o" }, "S", "<Plug>(leap-backward)")
end

function M.completion()
    local cmp = require("cmp")
    cmp.setup({
        mapping = cmp.mapping.preset.insert({
            ["<C-u>"] = cmp.mapping.scroll_docs(-4),
            ["<C-d>"] = cmp.mapping.scroll_docs(4),
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<C-e>"] = cmp.mapping.abort(),
            ["<CR>"] = cmp.mapping.confirm({
                select = false,
                behavior = cmp.ConfirmBehavior.Insert,
            }),
        }),
    })

    keymap(c, "<C-Space>", function()
        require("cmp").complete()
    end, default_settings)
end

return M
