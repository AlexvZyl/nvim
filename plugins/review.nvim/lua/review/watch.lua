local session = require("review.session")
local state = require("review.state")

local M = {}

local timer, watcher, safely

function M.refresh()
    local branch, merge_base, head_commit = session.branch, session.merge_base, session.head_commit
    if not session.load() then
        return
    end
    if session.branch ~= branch then
        state.load()
        vim.notify("Reviewing " .. session.branch .. " against " .. session.base_ref)
    end
    local render = require("review.render")
    -- Moving HEAD changes which changes are uncommitted.
    local moved = session.merge_base ~= merge_base or session.head_commit ~= head_commit
    if moved then
        render.attach_all()
    end
    require("review.deleted").refresh(moved)
    require("review.panel").refresh()
end

-- Debounced, as a rebase moves HEAD for every commit.
function M.schedule()
    if timer then
        timer:stop()
        timer:start(200, 0, vim.schedule_wrap(safely(M.refresh)))
    end
end

-- Watches the HEAD reflog, which git appends to whenever HEAD moves.
function M.start(run_safely)
    safely = run_safely
    timer = vim.uv.new_timer()
    watcher = vim.uv.new_fs_event()
    local reflog_path = session.git_dir .. "/logs/HEAD"
    local function start()
        watcher:start(reflog_path, {}, function(watch_error)
            if watch_error then
                return
            end
            -- Git may have replaced the file.
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
