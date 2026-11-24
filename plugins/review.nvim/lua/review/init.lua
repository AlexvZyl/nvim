local config = require("review.config")

-- Required on first use, so setup loads nothing until a review starts.
local function lazy(name)
    return setmetatable({}, {
        __index = function(_, key)
            return require(name)[key]
        end,
    })
end

local highlights = lazy("review.highlights")
local session = lazy("review.session")
local watch = lazy("review.watch")

local M = {}

local group = vim.api.nvim_create_augroup("review", { clear = true })
local key_namespace = vim.api.nvim_create_namespace("review_keys")

local function guarded(fn)
    return function(...)
        if not session.active() then
            return vim.notify("No review running, start one with :Review", vim.log.levels.WARN)
        end
        fn(...)
    end
end

function M.active()
    return session.active()
end

M.panel = guarded(function()
    require("review.panel").toggle()
end)

M.files = guarded(function(opts)
    require("review.picker").open(opts)
end)

M.reset = guarded(function()
    if session.load() then
        require("review.state").reset()
        require("review.panel").refresh()
    end
end)

-- A failing callback would error on every event, stop the review on the first one instead.
local function safely(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            pcall(M.stop)
            vim.schedule(function()
                vim.notify("review.nvim stopped after an error, run :Review to resume:\n" .. err, vim.log.levels.ERROR)
            end)
        end
    end
end

local function autocmd(event, callback)
    vim.api.nvim_create_autocmd(event, { group = group, callback = safely(callback) })
end

-- Of the buffer the event is for.
local function on_buf(fn)
    return function(args)
        fn(args.buf)
    end
end

local function create_autocmds()
    local panel = require("review.panel")
    local render = require("review.render")
    autocmd("ColorScheme", function()
        highlights.set()
        require("review.diagnostics").recolor()
    end)
    autocmd("BufEnter", on_buf(panel.follow))
    -- BufEnter as well: for a file not loaded yet, focus is put back after BufWinEnter.
    autocmd({ "BufEnter", "BufWinEnter" }, panel.guard)
    autocmd("BufWinEnter", on_buf(render.reveal))
    autocmd("WinScrolled", render.scrolled)
    autocmd("SafeState", render.settled)
    autocmd("WinResized", panel.resized)
    -- BufNewFile for deleted files.
    autocmd({ "BufReadPost", "BufNewFile", "BufWritePost" }, on_buf(render.attach))
    -- Saves and outside tools change what is in the diff without moving HEAD.
    autocmd({ "BufWritePost", "FocusGained" }, watch.schedule)
    autocmd("BufWipeout", on_buf(render.detach))
    autocmd({ "TextChanged", "TextChangedI" }, on_buf(render.update))
    vim.on_key(safely(require("review.scroll").key), key_namespace)
end

local function teardown()
    watch.stop()
    require("review.panel").close()
    vim.api.nvim_clear_autocmds({ group = group })
    vim.on_key(nil, key_namespace)
    require("review.render").detach_all()
    require("review.deleted").wipe()
    require("review.diagnostics").stop()
end

-- Starts reviewing against the ref, or switches to it, and opens the panel.
function M.start(ref)
    local panel = require("review.panel")
    ref = ref or session.ref or config.options.base
    if ref ~= session.ref then
        local switching = session.active()
        -- Keeps the current review when the ref is invalid.
        if not session.start(ref) then
            return
        end
        teardown()
        highlights.set()
        create_autocmds()
        require("review.diagnostics").start()
        watch.start(safely)
        require("review.render").attach_all()
        if not switching then
            vim.api.nvim_exec_autocmds("User", { pattern = "ReviewStart" })
        end
    end
    if not panel.is_open() then
        panel.toggle()
    end
end

function M.stop()
    if not session.active() then
        return
    end
    teardown()
    session.stop()
    vim.api.nvim_exec_autocmds("User", { pattern = "ReviewStop" })
end

function M.setup(opts)
    config.set(opts)
    vim.api.nvim_create_user_command("Review", function(args)
        M.start(args.args ~= "" and args.args or nil)
    end, {
        nargs = "?",
        complete = function(lead)
            return vim.tbl_filter(function(ref)
                return vim.startswith(ref, lead)
            end, require("review.git").refs())
        end,
    })
    vim.api.nvim_create_user_command("ReviewStop", M.stop, {})
    vim.api.nvim_create_user_command("ReviewReset", M.reset, {})
    if config.options.keymaps.files then
        vim.keymap.set("n", config.options.keymaps.files, M.files, { desc = "Review files" })
    end
end

return M
