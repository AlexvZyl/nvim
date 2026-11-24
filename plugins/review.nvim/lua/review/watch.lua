local session = require("review.session")
local state = require("review.state")

local M = {}

local timer, watcher, wrap

-- Reloads from git after HEAD or the working tree changed.
local function refresh()
    local source, merge_base, head = session.source, session.merge_base, session.head
    if not session.load() then
        return
    end
    if session.source ~= source then
        state.load()
        vim.notify("Reviewing " .. session.source .. " against " .. session.ref)
    end
    local render = require("review.render")
    -- What is committed moves with HEAD, which decides which changes are local.
    local moved = session.merge_base ~= merge_base or session.head ~= head
    for _, buf in ipairs(moved and vim.api.nvim_list_bufs() or {}) do
        if vim.api.nvim_buf_is_loaded(buf) then
            render.attach(buf)
        end
    end
    render.refresh_deleted(moved)
    require("review.panel").refresh()
end

-- Once for a burst of changes, a rebase moves HEAD for every commit.
function M.schedule()
    if timer then
        timer:stop()
        timer:start(200, 0, vim.schedule_wrap(wrap(refresh)))
    end
end

-- Git appends to the HEAD reflog whenever HEAD moves, and the merge base only changes when HEAD does.
-- Refreshes run through `safe`, which handles their errors.
function M.start(safe)
    wrap = safe
    timer = vim.uv.new_timer()
    watcher = vim.uv.new_fs_event()
    local reflog = session.git_dir .. "/logs/HEAD"
    local function start()
        watcher:start(reflog, {}, function(err)
            if err then
                return
            end
            -- Restarted in case git replaced the file.
            watcher:stop()
            start()
            M.schedule()
        end)
    end
    start()
end

function M.stop()
    for _, handle in ipairs({ timer, watcher }) do
        if not handle:is_closing() then
            handle:close()
        end
    end
    timer, watcher = nil, nil
end

return M
