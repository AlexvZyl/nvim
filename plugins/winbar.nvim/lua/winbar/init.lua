local M = {}

local function filename()
    local name = vim.api.nvim_buf_get_name(0)
    return name ~= "" and vim.fn.fnamemodify(name, ":t") or ""
end

local function parent()
    local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":h:t")
    return dir == "." and "" or dir .. "/"
end

local function file_icon()
    if vim.bo.filetype == "help" then
        return "󰞋"
    end
    return require("nvim-web-devicons").get_icon_by_filetype(vim.bo.filetype)
end

local function modifiable()
    return not vim.tbl_contains({ "nofile", "prompt", "help" }, vim.bo.buftype) and not vim.bo.readonly
end

local options = {
    -- Filetypes left alone, like ones that set their own.
    exclude = {},
    -- By filetype or buftype: { icon = string, name = function, hide_modified = boolean }.
    bars = {
        qf = {
            icon = "",
            name = function()
                return "QuickFix"
            end,
        },
        netrw = {
            icon = "",
            name = function()
                return "Netrw"
            end,
        },
        oil = {
            icon = " ",
            name = function()
                return (vim.fn.expand("%"):gsub("oil://", ""))
            end,
        },
        checkhealth = {
            icon = "󰋠",
            name = function()
                return "Healthcheck"
            end,
        },
        man = {
            icon = "󰌽",
            name = function()
                return "man/" .. filename():gsub("man//", "")
            end,
        },
        terminal = {
            icon = "",
            name = function()
                return "Terminal"
            end,
        },
        dashboard = {
            icon = " ",
            name = function()
                return vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
            end,
        },
    },
}

function M.get_winbar()
    local prefix = "  "
    local modified = ""
    if not modifiable() then
        modified = " "
    elseif vim.bo.modified then
        modified = " ●"
    end

    local bar = options.bars[vim.bo.filetype] or options.bars[vim.bo.buftype]
    if bar then
        return prefix .. bar.icon .. " " .. bar.name() .. (bar.hide_modified and "" or modified)
    end

    local icon = file_icon() or ""
    local name = filename()
    if name == "" then
        name = "[No Name]"
        icon = " "
    end
    return prefix .. icon .. " " .. parent() .. name .. modified
end

function M.set_winbar()
    if vim.tbl_contains(options.exclude, vim.bo.filetype) then
        return
    end
    if vim.api.nvim_win_get_config(0).relative ~= "" then
        return
    end
    vim.opt_local.winbar = M.get_winbar()
end

function M.setup(opts)
    options = vim.tbl_deep_extend("force", options, opts or {})
    local events = { "BufWritePost", "BufWinEnter", "BufFilePost", "WinEnter", "TermOpen", "BufReadPost" }
    -- Not available in all versions.
    if vim.fn.exists("##BufModifiedSet") == 1 then
        table.insert(events, "BufModifiedSet")
    end
    vim.api.nvim_create_autocmd(events, {
        group = vim.api.nvim_create_augroup("winbar", { clear = true }),
        callback = M.set_winbar,
    })
end

return M
