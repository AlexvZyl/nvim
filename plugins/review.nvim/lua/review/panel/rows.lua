-- Builds the panel's rows: pending files grouped by directory, or a done message.
local config = require("review.config")
local session = require("review.session")

local M = {}

local FOLDER = ""
M.DONE = "󰄴"

-- How each file is shown, by path. Reset when the grouping depth changes.
local layouts, layouts_depth = {}, nil

local function layout(path)
    if layouts_depth ~= config.options.depth then
        layouts, layouts_depth = {}, config.options.depth
    end
    if not layouts[path] then
        local dirs = vim.split(vim.fs.dirname(path), "/", { plain = true })
        local name = vim.fn.fnamemodify(path, ":t")
        local icon, icon_hl = require("nvim-web-devicons").get_icon(name, nil, { default = true })
        layouts[path] = {
            dir = dirs[1] == "." and "" or table.concat(dirs, "/", 1, math.min(config.options.depth, #dirs)),
            text = icon .. " " .. name,
            icon_end = #icon,
            icon_hl = icon_hl,
        }
    end
    return layouts[path]
end

-- Pending files by directory, and the directories sorted.
local function group_by_dir(files)
    local by_dir, dirs = {}, {}
    for _, file in ipairs(files) do
        if file:needs_review() then
            local dir = layout(file.path).dir
            if not by_dir[dir] then
                by_dir[dir] = {}
                table.insert(dirs, dir)
            end
            table.insert(by_dir[dir], file)
        end
    end
    table.sort(dirs)
    return by_dir, dirs
end

-- "+added -removed" as chunks.
local function count_chunks(file)
    local chunks = {}
    local lines_added, lines_removed = file:counts_to_show()
    for _, count in ipairs({ { lines_added, "+", "ReviewPanelAdded" }, { lines_removed, "-", "ReviewPanelRemoved" } }) do
        local number, sign, group = count[1], count[2], count[3]
        if (number or 0) > 0 then
            table.insert(chunks, { sign .. number .. " ", group })
        end
    end
    return chunks
end

-- A row's extmarks as { col, opts }: icon highlight, dot, directory header, strikethrough and counts.
local function extmarks(file, text, header)
    local file_layout = layout(file.path)
    local dot = file:changed_after_review() and "ReviewChanged" or file:is_unseen() and "ReviewNew"
    local found = {
        {
            0,
            {
                end_col = file_layout.icon_end,
                hl_group = file_layout.icon_hl,
                virt_text = dot and { { " ●", dot } } or nil,
                virt_lines = header and { { { " " .. FOLDER .. (header ~= "" and " " .. header or ""), "ReviewPanelDir" } } } or nil,
                virt_lines_above = true,
                virt_lines_leftcol = true,
            },
        },
    }
    if file.is_deleted then
        table.insert(found, { file_layout.icon_end + 1, { end_col = #text, hl_group = "ReviewPanelDeleted" } })
    end
    local counts = count_chunks(file)
    if #counts > 0 then
        table.insert(found, { 0, { virt_text = counts, virt_text_pos = "right_align" } })
    end
    return found
end

-- Rows of files to review: { file, text, header, ends_group, extmarks }. Header is the directory, on a group's first.
function M.build(files)
    local by_dir, dirs = group_by_dir(files)
    local rows = {}
    for _, dir in ipairs(dirs) do
        for i, file in ipairs(by_dir[dir]) do
            table.insert(rows, { file = file, text = layout(file.path).text, header = i == 1 and dir or nil })
        end
        rows[#rows].ends_group = true
    end
    if config.options.view == "since_review" then
        session.count_lines_since_review(vim.tbl_map(function(row)
            return row.file
        end, rows))
    end
    for _, row in ipairs(rows) do
        row.extmarks = extmarks(row.file, row.text, row.header)
    end
    return rows
end

-- The done message as virtual lines, centered in the window.
function M.done(reviewed_count, width, height)
    local undo = config.options.keymaps.undo
    local message = { { M.DONE, "ReviewSignAdd" } }
    if reviewed_count == 0 then
        table.insert(message, { "Nothing to review", "Comment" })
    else
        table.insert(message, { "Review complete", "Normal" })
        table.insert(message, { ("%d file%s reviewed"):format(reviewed_count, reviewed_count == 1 and "" or "s"), "Comment" })
        if undo then
            vim.list_extend(message, { { "", "Comment" }, { undo .. " to undo", "Comment" } })
        end
    end
    -- The empty buffer line takes the first row.
    local lines = {}
    for _ = 1, math.floor((height - #message) / 2) - 1 do
        table.insert(lines, { { "", "Normal" } })
    end
    for _, chunk in ipairs(message) do
        local padding = math.max(math.floor((width - vim.fn.strdisplaywidth(chunk[1])) / 2), 0)
        -- Own chunk, so it does not get the text's background.
        table.insert(lines, { { string.rep(" ", padding), "Normal" }, chunk })
    end
    return lines
end

return M
