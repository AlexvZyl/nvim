local M = {}

local state = { win = nil, buf = nil, guicursor = nil, augroup = nil }

local function close_overlay()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        pcall(vim.api.nvim_win_close, state.win, true)
    end
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
    end
    state.win, state.buf = nil, nil
end

local function get_num_updates()
    local updates = 0
    for _, plugin in pairs(require("lazy.core.config").plugins) do
        if plugin._.updates then
            updates = updates + 1
        end
    end
    return updates
end

local function cover_intro_bottom()
    close_overlay()

    local s = require("lazy").stats()
    local lines = {
        string.format("              󰥔 Startup: %.2fms            ", s.startuptime),
        string.format("                Plugins: %d/%d", s.loaded, s.count),
        string.format("                  Updates: %d", get_num_updates()),
    }

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    state.buf = buf
    local width = 44
    state.win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        row = math.floor(vim.o.lines / 2) + 7,
        col = math.floor((vim.o.columns - width) / 2) - 1,
        width = width,
        height = #lines,
        style = "minimal",
        border = "none",
        focusable = false,
    })
    vim.wo[state.win].winhighlight = "Normal:Comment"
end

function M.destroy()
    close_overlay()
    if state.guicursor then
        vim.o.guicursor = state.guicursor
        state.guicursor = nil
    end
    pcall(vim.api.nvim_del_augroup_by_name, "dashboard")
    require("alex.native.statuscolumn").default()
end

local function setup_cursor()
    state.guicursor = vim.o.guicursor
    vim.o.guicursor = "a:DashboardHiddenCursor"
    vim.api.nvim_set_hl(0, "DashboardHiddenCursor", { blend = 100, nocombine = true })

    state.augroup = vim.api.nvim_create_augroup("dashboard", { clear = true })

    vim.api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineLeave" }, {
        group = state.augroup,
        callback = function(ev)
            if not state.guicursor then
                return
            end
            if ev.event == "CmdlineEnter" then
                vim.o.guicursor = state.guicursor
            elseif vim.bo.filetype == "dashboard" then
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
            cover_intro_bottom()
        end,
    })

    vim.api.nvim_create_autocmd({ "BufLeave", "BufWipeout", "BufDelete" }, {
        buffer = 0,
        once = true,
        callback = M.destroy,
    })

    vim.api.nvim_create_autocmd("ModeChanged", {
        buffer = 0,
        callback = function()
            if not vim.v.event.new_mode:match("[nc]") then
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
                    "n",
                    false
                )
            end
        end,
    })

    vim.api.nvim_create_autocmd("VimResized", {
        group = state.augroup,
        callback = function()
            if vim.bo.filetype ~= "dashboard" then
                return
            end
            cover_intro_bottom()
        end,
    })

    vim.api.nvim_create_autocmd("User", {
        pattern = "LazyRender",
        group = state.augroup,
        callback = function()
            if vim.bo.filetype == "dashboard" then
                cover_intro_bottom()
            end
        end,
    })
end

function M.setup()
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
