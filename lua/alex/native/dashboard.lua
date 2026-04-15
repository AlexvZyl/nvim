local M = {}

local state = { wins = {}, bufs = {}, guicursor = nil }

local function chunk_width(chunks)
    return vim.iter(chunks):fold(0, function(w, c)
        return w + vim.api.nvim_strwidth(c[1])
    end)
end

local function open_panel(left, right, row, col, width, right_col)
    local buf = vim.api.nvim_create_buf(false, true)
    local ns = vim.api.nvim_create_namespace("dashboard")
    local height = #left
    local blank = {}
    for i = 1, height do
        blank[i] = ""
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, blank)
    for i = 1, height do
        vim.api.nvim_buf_set_extmark(
            buf,
            ns,
            i - 1,
            0,
            { virt_text = left[i], virt_text_pos = "overlay" }
        )
        if right[i] then
            vim.api.nvim_buf_set_extmark(
                buf,
                ns,
                i - 1,
                0,
                { virt_text = right[i], virt_text_win_col = right_col }
            )
        end
    end
    vim.bo[buf].modifiable = false
    local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
        border = "none",
        focusable = false,
    })
    table.insert(state.bufs, buf)
    table.insert(state.wins, win)
end

function M.destroy()
    for _, w in ipairs(state.wins) do
        pcall(vim.api.nvim_win_close, w, true)
    end
    for _, b in ipairs(state.bufs) do
        pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
    if state.guicursor then
        vim.o.guicursor = state.guicursor
    end
    pcall(vim.api.nvim_del_augroup_by_name, "dashboard_cmdline")
    pcall(vim.api.nvim_del_augroup_by_name, "dashboard_resize")
    require("alex.native.statuscolumn").default()
    state = { wins = {}, bufs = {}, guicursor = nil }
end

function M.show_stats()
    local s = require("lazy").stats()

    local left = {
        { { string.rep("─", 0), "NonText" } },
        { { " ", "Statement" }, { string.format("Startup: %.2fms", s.startuptime), "Normal" } },
        {
            { "󰚥 ", "Statement" },
            { string.format("Plugins: %d/%d", s.loaded, s.count), "Normal" },
        },
    }
    local right = {
        nil,
        { { ":Lazy", "Statement" }, { " [update|profile]", "Normal" } },
        { { "<Leader>e", "Statement" } },
    }

    local gap = 4
    local lw = math.max(chunk_width(left[2]), chunk_width(left[3]))
    local rw = math.max(chunk_width(right[2]), chunk_width(right[3]))
    local total_w = lw + gap + rw
    local right_col = lw + gap

    left[1][1][1] = string.rep("─", total_w)

    local row = math.floor((vim.o.lines - #left) / 2) + 7
    local col = math.floor((vim.o.columns - total_w) / 2)
    open_panel(left, right, row, col, total_w, right_col)
end

local function setup_cursor()
    state.guicursor = vim.o.guicursor
    vim.o.guicursor = "a:DashboardHiddenCursor"
    vim.api.nvim_set_hl(0, "DashboardHiddenCursor", { blend = 100, nocombine = true })

    local cmdline_group = vim.api.nvim_create_augroup("dashboard_cmdline", { clear = true })

    vim.api.nvim_create_autocmd("CmdlineEnter", {
        group = cmdline_group,
        callback = function()
            if state.guicursor then
                vim.o.guicursor = state.guicursor
            end
        end,
    })

    vim.api.nvim_create_autocmd("CmdlineLeave", {
        group = cmdline_group,
        callback = function()
            if state.guicursor and vim.bo.filetype == "dashboard" then
                vim.o.guicursor = "a:DashboardHiddenCursor"
            end
        end,
    })
end

local function create_buffer_autocmds()
    vim.api.nvim_create_autocmd("UIEnter", {
        once = true,
        callback = function()
            vim.wo[0].number = false
            vim.wo[0].relativenumber = false
            vim.wo[0].statuscolumn = " "
            M.show_stats()
        end,
    })

    vim.api.nvim_create_autocmd({ "BufLeave", "BufWipeout", "BufDelete" }, {
        buffer = 0,
        once = true,
        callback = M.destroy,
    })

    -- Only allow normal and cmdline modes.
    vim.api.nvim_create_autocmd("ModeChanged", {
        buffer = 0,
        callback = function()
            if not vim.v.event.new_mode:match("[nc]") then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
            end
        end,
    })

    -- Keep floating windows at correct spot.
    vim.api.nvim_create_autocmd("VimResized", {
        group = vim.api.nvim_create_augroup("dashboard_resize", { clear = true }),
        callback = function()
            if vim.bo.filetype ~= "dashboard" then
                return
            end
            for _, w in ipairs(state.wins) do
                pcall(vim.api.nvim_win_close, w, true)
            end
            for _, b in ipairs(state.bufs) do
                pcall(vim.api.nvim_buf_delete, b, { force = true })
            end
            state.wins = {}
            state.bufs = {}
            M.show_stats()
        end,
    })
end

function M.setup()
    -- Probably opening a file, so don't mess with dashboard.
    -- TODO: This is probably not very reliable.
    if vim.fn.argc() > 0 then
        return
    end

    vim.bo[0].filetype = "dashboard"
    vim.bo[0].modifiable = false
    setup_cursor()
    create_buffer_autocmds()
end

M.setup()

return M
