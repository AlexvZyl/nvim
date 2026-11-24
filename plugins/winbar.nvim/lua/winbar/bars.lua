local buffer = require("winbar.buffer")

-- Built-in bars by filetype or buftype.
return {
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
            return "man/" .. buffer.filename():gsub("man//", "")
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
}
