local M = {}

-- Display the difference in commits between local and head.
local Job = require 'plenary.job'
function M.get_git_compare()
    if M.current_window_floating() then
        return ''
    end
    if M.get_current_buftype() == 'nofile' then return '' end

    -- Get the path of the current directory.
    local curr_dir = vim.api.nvim_buf_get_name(0):match('(.*' .. '/' .. ')')

    if false then
        -- Run job to get git.
        local result = Job:new({
            command = 'git',
            cwd = curr_dir,
            args = { 'rev-list', '--left-right', '--count', 'HEAD...@{upstream}' },
        })
            :sync(100)[1]

        -- Process the result.
        if type(result) ~= 'string' then return '' end
        local ok, ahead, behind = pcall(string.match, result, '(%d+)%s*(%d+)')
        if not ok then return '' end

        local string = ''
        if behind ~= '0' then string = string .. '󱦳' .. behind end
        if ahead ~= '0' then string = string .. '󱦲' .. ahead end
        return string
    end

    return ''
end

function M.is_recording() return vim.fn.reg_recording() ~= '' end

function M.get_recording_icon()
    if M.is_recording() then
        return '  '
    else
        return ''
    end
end

return M
