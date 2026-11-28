-- Text, File and Diff: the review's data. None of them knows about buffers or drawing.
local git = require("review.git")

local M = {}

-- Text

---@class LineRange
---@field start integer First byte of the line in the text's data
---@field finish integer Last byte, before its newline. Below start when the line is empty.

-- Text is a string with the byte range of each line, built once on creation.
---@class Text
---@field data string
---@field lines LineRange[]
local Text = {}
Text.__index = Text
M.Text = Text

-- Lines split at "\n", like vim.split: a trailing newline gives a last, empty line.
function Text.new(data)
    local lines, start = {}, 1
    while true do
        local newline = data:find("\n", start, true)
        if not newline then
            break
        end
        lines[#lines + 1] = { start = start, finish = newline - 1 }
        start = newline + 1
    end
    lines[#lines + 1] = { start = start, finish = #data }
    return setmetatable({ data = data, lines = lines }, Text)
end

function Text:line_count()
    return #self.lines
end

function Text:line(i)
    local range = self.lines[i]
    return self.data:sub(range.start, range.finish)
end

-- Lines first to last as one string, joined by their newlines.
function Text:range(first, last)
    return self.data:sub(self.lines[first].start, self.lines[last].finish)
end

-- File

-- File is a file at a revision, as git has it.
---@class File
---@field path string From the cwd
---@field revision string A ref, commit or blob hash
---@field text Text? Nil when git has no file there
local File = {}
File.__index = File
M.File = File

-- Data nil means git has no file there.
function File.new(path, revision, data)
    return setmetatable({ path = path, revision = revision, text = data and Text.new(data) }, File)
end

function File:is_binary()
    return self.text ~= nil and self.text.data:find("\0", 1, true) ~= nil
end

-- Files by path, then revision, read by one git process. A revision can be a function of the path from the cwd,
-- giving the object to read, or nil for none.
function M.read_each(paths, revisions)
    local contents = git.show_each(paths, revisions)
    local files = {}
    for i, path in ipairs(paths) do
        local cwd_path = vim.fn.fnamemodify(path, ":.")
        files[i] = {}
        for j, revision in ipairs(revisions) do
            local resolved = type(revision) == "function" and revision(cwd_path) or revision
            files[i][j] = resolved and File.new(cwd_path, resolved, contents[i][j])
        end
    end
    return files
end

-- Diff

---@class Hunk
---@field old_start integer
---@field old_count integer
---@field new_start integer The line before it when new_count is 0
---@field new_count integer

-- Diff is how one Text changed into another.
---@class Diff
---@field old_text Text
---@field new_text Text
---@field hunks Hunk[] In file order
local Diff = {}
Diff.__index = Diff
M.Diff = Diff

function Diff.new(old, new)
    local hunks = {}
    for _, hunk in ipairs(vim.text.diff(old.data, new.data, { result_type = "indices", indent_heuristic = true })) do
        local old_start, old_count, new_start, new_count = unpack(hunk)
        hunks[#hunks + 1] = { old_start = old_start, old_count = old_count, new_start = new_start, new_count = new_count }
    end
    return setmetatable({ old_text = old, new_text = new, hunks = hunks }, Diff)
end

-- No changes, without diffing.
function Diff.unchanged(text)
    return setmetatable({ old_text = text, new_text = text, hunks = {} }, Diff)
end

-- Lines of new_text added or changed.
function Diff:added_lines()
    local lines = {}
    for _, hunk in ipairs(self.hunks) do
        for line = hunk.new_start, hunk.new_start + hunk.new_count - 1 do
            lines[#lines + 1] = line
        end
    end
    return lines
end

---@class DeletedLine
---@field old_line integer Its line in old_text
---@field index integer Its place in its hunk
---@field row integer The 0-based row of new_text it is drawn at
---@field hunk Hunk

-- Lines of old_text deleted, in order. A pure deletion is drawn above the line after it.
function Diff:deleted_lines()
    local deleted = {}
    for _, hunk in ipairs(self.hunks) do
        local row = hunk.new_count > 0 and hunk.new_start - 1 or hunk.new_start
        for index = 1, hunk.old_count do
            deleted[#deleted + 1] = { old_line = hunk.old_start + index - 1, index = index, row = row, hunk = hunk }
        end
    end
    return deleted
end

-- Where each deleted line of old_text sits between new_text's lines: after the line before it, or before the lines replacing
-- it.
function Diff:deleted_positions()
    local positions = {}
    for _, hunk in ipairs(self.hunks) do
        local position = hunk.new_count == 0 and hunk.new_start + 0.5 or hunk.new_start - 0.5
        for index = 1, hunk.old_count do
            positions[hunk.old_start + index - 1] = position
        end
    end
    return positions
end

return M
