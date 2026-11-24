local h = require("tests.helpers")

local T = {}

-- file.txt deleted, committed or only locally, and other.txt added, with the review running.
local function setup(committed)
    h.repo(h.lines(5), h.lines(5))
    vim.fn.writefile({ "a" }, "other.txt")
    h.git("add", ".")
    h.git("commit", "-qm", "other")
    if committed then
        h.git("rm", "-q", "file.txt")
        h.git("commit", "-qm", "delete")
    else
        os.remove("file.txt")
    end
    return h.review()
end

-- Selects the deleted file in the panel.
local function open(panel)
    vim.api.nvim_set_current_win(panel)
    vim.fn.cursor(vim.fn.search("file.txt$"), 1)
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
end

local function selected(panel_buf)
    for _, mark in ipairs(h.marks(panel_buf, "review_panel", 1, vim.api.nvim_buf_line_count(panel_buf) + 1)) do
        if mark[4].line_hl_group == "ReviewPanelLine" then
            return vim.api.nvim_buf_get_lines(panel_buf, mark[2], mark[2] + 1, true)[1]
        end
    end
end

function T.a_file_deleted_locally_has_the_local_style()
    local main, panel = setup(false)
    open(panel)
    local buf = vim.api.nvim_win_get_buf(main)
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), h.lines(5)), "not the old contents")
    local mark = h.marks(buf, "review", 1, 2)[1]
    assert(mark and mark[4].sign_text == "╎ ", vim.inspect(mark))
    assert(mark[4].line_hl_group == "ReviewLocalDelete" and mark[4].number_hl_group == "ReviewLocalDeleteNr")
    require("review").stop()
end

function T.deleted_file_buffers_go_when_the_review_stops()
    local main, panel = setup(true)
    open(panel)
    require("review").stop()
    assert(vim.fn.bufnr("review://file.txt") == -1, "buffer left")
    assert(vim.api.nvim_win_is_valid(main), "window closed")
end

function T.deleted_file_buffers_go_when_switching_ref()
    local _, panel = setup(true)
    h.git("tag", "other", "dev")
    open(panel)
    require("review").start("other")
    assert(vim.fn.bufnr("review://file.txt") == -1, "buffer left")
    require("review").stop()
end

function T.the_panel_follows_to_a_deleted_file()
    local main, panel, panel_buf = setup(true)
    open(panel)
    local deleted = vim.api.nvim_win_get_buf(main)
    vim.api.nvim_set_current_win(main)
    vim.cmd.edit("other.txt")
    assert(selected(panel_buf):match("other.txt$"), selected(panel_buf))
    vim.cmd.buffer(deleted)
    assert(selected(panel_buf):match("file.txt$"), selected(panel_buf))
    require("review").stop()
end

-- Without going through the panel, the file is empty with what was in it as deleted lines above.
function T.editing_a_deleted_file_shows_it_as_deleted_lines()
    local main = setup(true)
    vim.api.nvim_set_current_win(main)
    vim.cmd.edit("file.txt")
    h.flush()
    local marks = h.marks(vim.api.nvim_get_current_buf(), "review_deleted", 1, 1)
    assert(#marks == 1 and #h.virt_lines(marks[1]) == 5, vim.inspect(marks))
    assert(vim.fn.winsaveview().topfill == 5, "deleted lines above the top not shown")
    require("review").stop()
end

return T
