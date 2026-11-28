local config = require("review.config")

-- Requires on first use, so setup loads nothing.
local function lazy(name)
    return setmetatable({}, {
        __index = function(_, key)
            return require(name)[key]
        end,
    })
end

local session = lazy("review.session")
local git = lazy("review.git")

local M = {}

local augroup = vim.api.nvim_create_augroup("review", { clear = true })
local key_namespace = vim.api.nvim_create_namespace("review_keys")

local function when_active(fn)
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

M.panel = when_active(function()
    require("review.panel").toggle()
end)

local other_view = { all = "since_review", since_review = "all" }

-- Sets the view option, or returns it.
function M.view(view)
    if not view then
        return config.options.view
    end
    assert(other_view[view], "unknown view " .. view)
    config.options.view = view
    if session.active() then
        require("review.render").attach_all()
        require("review.panel").refresh()
    end
end

function M.toggle_view()
    M.view(other_view[M.view()])
end

M.files = when_active(function(opts)
    -- Loading the extension runs its setup with telescope's config.
    require("telescope").load_extension("review").pick(opts)
end)

M.reset = when_active(function()
    if session.reload() then
        session.reset_progress()
        require("review.panel").refresh()
    end
end)

-- Stops the review on the first error, instead of erroring on every event.
local function safely(fn)
    return function(...)
        local ok, message = pcall(fn, ...)
        if not ok then
            pcall(M.stop)
            vim.schedule(function()
                vim.notify("review.nvim stopped after an error, run :Review to resume:\n" .. message, vim.log.levels.ERROR)
            end)
        end
    end
end

-- Reloads from git after HEAD moved, a save or focus returning.
function M.refresh()
    local branch, merge_base, head_commit = session.branch, session.merge_base, session.head_commit
    if not session.reload() then
        return
    end
    if session.branch ~= branch then
        session.load_progress()
        vim.notify("Reviewing " .. session.branch .. " against " .. session.base_ref)
    end
    -- Moving HEAD changes which changes are uncommitted.
    local moved = session.merge_base ~= merge_base or session.head_commit ~= head_commit
    if moved then
        require("review.render").attach_all()
    end
    require("review.deleted").refresh(moved)
    require("review.panel").refresh()
end

local function autocmd(event, callback)
    vim.api.nvim_create_autocmd(event, { group = augroup, callback = safely(callback) })
end

local function with_buf(fn)
    return function(args)
        fn(args.buf)
    end
end

local function create_autocmds()
    local panel = require("review.panel")
    local render = require("review.render")
    autocmd("ColorScheme", function()
        config.set_highlights()
        require("review.diagnostics").recolor()
    end)
    autocmd("BufEnter", with_buf(panel.follow))
    -- BufEnter too, as unloaded files get focus back after BufWinEnter.
    autocmd({ "BufEnter", "BufWinEnter" }, panel.guard)
    autocmd("BufWinEnter", with_buf(render.reveal))
    autocmd("WinScrolled", render.scrolled)
    autocmd("SafeState", render.settled)
    autocmd("WinResized", panel.resized)
    autocmd("VimResized", panel.fit)
    autocmd("OptionSet", panel.option_set)
    -- BufNewFile for deleted files.
    autocmd({ "BufReadPost", "BufNewFile", "BufWritePost" }, with_buf(render.attach))
    -- Saves and outside tools change the diff without moving HEAD.
    autocmd({ "BufWritePost", "FocusGained" }, git.schedule_change)
    -- Unloaded buffers have no lines to draw on.
    autocmd("BufUnload", with_buf(render.detach))
    -- TextChangedP while the completion menu is open.
    autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, with_buf(render.update))
    vim.on_key(safely(require("review.scroll").key), key_namespace)
end

local function teardown()
    git.unwatch()
    require("review.panel").close()
    vim.api.nvim_clear_autocmds({ group = augroup })
    vim.on_key(nil, key_namespace)
    require("review.render").detach_all()
    require("review.deleted").wipe()
    require("review.diagnostics").stop()
end

-- Starts or switches the review, and opens the panel.
function M.start(base_ref)
    local panel = require("review.panel")
    base_ref = base_ref or session.base_ref or config.options.base
    local started = base_ref ~= session.base_ref
    if started then
        local switching = session.active()
        -- Keeps the current review on an invalid ref.
        if not session.start(base_ref) then
            return
        end
        teardown()
        config.set_highlights()
        create_autocmds()
        require("review.diagnostics").start()
        git.watch(session.git_dir, safely(M.refresh))
        -- Before attaching, as the since_review view diffs against reviewed versions.
        session.load_progress()
        require("review.render").attach_all()
        if not switching then
            vim.api.nvim_exec_autocmds("User", { pattern = "ReviewStart" })
        end
    end
    if not panel.is_open() then
        panel.toggle(started)
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
            end, git.refs())
        end,
    })
    vim.api.nvim_create_user_command("ReviewStop", M.stop, {})
    vim.api.nvim_create_user_command("ReviewReset", M.reset, {})
end

return M
