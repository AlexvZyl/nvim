local h = require("tests.helpers")

local T = {}

-- Line 3 changed by the branch, reviewed, then line 9 changed by a commit after. Returns the file's buffer and the
-- panel, focused on the file.
local function setup(reviewed)
    h.repo(h.lines(12), h.edit(h.lines(12), { [3] = "mod 3" }))
    local main, panel = h.review("file.txt")
    if reviewed then
        require("review.state").review({ require("review.session").files[1].key }, 1)
    end
    h.commit({ ["file.txt"] = h.edit(h.lines(12), { [3] = "mod 3", [9] = "mod 9" }) })
    require("review.watch").refresh()
    vim.api.nvim_set_current_win(main)
    -- As committed, not the lines read before.
    vim.cmd("silent edit!")
    return vim.api.nvim_get_current_buf(), panel
end

-- The lines added and removed the panel shows for the file, like "+1 -1".
local function counted(panel)
    local panel_buf = vim.api.nvim_win_get_buf(panel)
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(panel_buf, -1, 0, -1, { details = true })) do
        if mark[4].virt_text_pos == "right_align" then
            return vim.trim(table.concat(vim.tbl_map(function(chunk)
                return chunk[1]
            end, mark[4].virt_text)))
        end
    end
end

local function finish()
    require("review").view("since_review")
    require("review").stop()
end

-- The lines signed as changed.
local function signed(buf)
    return vim.tbl_map(function(mark)
        return mark[2] + 1
    end, h.marks(buf, "review", 1, vim.api.nvim_buf_line_count(buf)))
end

function T.since_review_shows_the_changes_after_the_review()
    local buf = setup(true)
    require("review").view("since_review")
    local since = signed(buf)
    require("review").toggle_view()
    local all = signed(buf)
    finish()
    assert(vim.deep_equal(since, { 9 }), vim.inspect(since))
    assert(vim.deep_equal(all, { 3, 9 }), vim.inspect(all))
end

function T.since_review_shows_files_not_reviewed_in_full()
    local buf = setup(false)
    require("review").view("since_review")
    local since = signed(buf)
    finish()
    assert(vim.deep_equal(since, { 3, 9 }), vim.inspect(since))
end

function T.reviewing_a_file_since_review_clears_it()
    local buf, panel = setup(false)
    require("review").view("since_review")
    vim.api.nvim_set_current_win(panel)
    h.press("ggdd")
    local reviewed = signed(buf)
    h.press("u")
    local undone = signed(buf)
    finish()
    assert(#reviewed == 0, vim.inspect(reviewed))
    assert(vim.deep_equal(undone, { 3, 9 }), vim.inspect(undone))
end

-- Like after a force push, once git pruned the blob the file was reviewed at.
function T.since_review_shows_everything_when_the_reviewed_blob_is_gone()
    local buf = setup(true)
    local session = require("review.session")
    local name = (session.source .. ".." .. session.ref):gsub("/", "%%")
    h.write(session.git_dir .. "/review/" .. name .. ".json", vim.json.encode({ reviewed = { [session.files[1].key] = ("0"):rep(40) } }))
    require("review.state").load()
    require("review").view("since_review")
    local since = signed(buf)
    finish()
    assert(vim.deep_equal(since, { 3, 9 }), vim.inspect(since))
end

function T.the_panel_counts_the_lines_changed_since_the_review()
    local _, panel = setup(true)
    require("review").view("since_review")
    local since = counted(panel)
    require("review").toggle_view()
    local all = counted(panel)
    finish()
    assert(since == "+1 -1", since)
    assert(all == "+2 -2", all)
end

function T.the_panel_counts_files_not_reviewed_in_full()
    local _, panel = setup(false)
    require("review").view("since_review")
    local since = counted(panel)
    finish()
    assert(since == "+2 -2", since)
end

return T
