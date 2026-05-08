vim.opt.autocomplete = true
vim.opt.pumheight = 10
vim.opt.completeopt = { "menuone", "noselect", "fuzzy", "popup" }
vim.opt.pumborder = "rounded"

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

        assert(client)
        if client:supports_method('textDocument/completion') then
            vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = false })
        else
            vim.schedule(function()
                vim.notify("LSP does not support auto complete", vim.log.levels.WARN)
            end)
        end
    end,
})

vim.opt.complete:append('o')

-- VIBE CODED SHUOLD PROBABLY BE REMOVED.

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

