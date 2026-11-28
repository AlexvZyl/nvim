-- Text, File and Diff: the review's data. None of them knows about buffers or drawing.
local git = require("review.git")

local M = {}

-- Text

-- Text is a string with where each line starts. Only starts are stored, as a line ends 2 bytes before the next
-- starts, skipping its newline. That halves the memory.
---@class Text
---@field data string
---@field line_starts integer[]? First byte of each line, then one past the end for the last line to end at. Nil until indexed.
---@field read_lines table<integer, string>? Lines already read, as deleted lines are read on every render
local Text = {}
Text.__index = Text
M.Text = Text

function Text.new(data)
    return setmetatable({ data = data }, Text)
end

-- Finds where lines start, split at "\n" like vim.split: a trailing newline gives a last, empty line. Only Texts
-- whose lines are read need it, so a buffer's Text, which is only diffed, is never indexed.
function Text:index_lines()
    if self.line_starts then
        return self
    end
    local data, line_starts, start = self.data, {}, 1
    while true do
        line_starts[#line_starts + 1] = start
        local newline = data:find("\n", start, true)
        if not newline then
            break
        end
        start = newline + 1
    end
    -- As if the text ended in a newline, so the last line ends like the others.
    line_starts[#line_starts + 1] = #data + 2
    self.line_starts, self.read_lines = line_starts, {}
    return self
end

-- The last byte of the line, before its newline. Below its start when the line is empty.
function Text:line_end(i)
    return self:index_lines().line_starts[i + 1] - 2
end

function Text:line_count()
    return #self:index_lines().line_starts - 1
end

function Text:line(i)
    self:index_lines()
    local line = self.read_lines[i]
    if not line then
        line = self.data:sub(self.line_starts[i], self:line_end(i))
        self.read_lines[i] = line
    end
    return line
end

function Text:line_length(i)
    return self:line_end(i) - self:index_lines().line_starts[i] + 1
end

-- Lines first to last as one string, joined by their newlines.
function Text:range(first, last)
    return self.data:sub(self:index_lines().line_starts[first], self:line_end(last))
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

-- Iterates the lines of new_text added or changed. An iterator, so nothing is built on every edit.
function Diff:each_added_line()
    local hunks, hunk_index, line, last = self.hunks, 0, 0, 0
    return function()
        while line >= last do
            hunk_index = hunk_index + 1
            local hunk = hunks[hunk_index]
            if not hunk then
                return nil
            end
            line, last = hunk.new_start - 1, hunk.new_start + hunk.new_count - 1
        end
        line = line + 1
        return line
    end
end

-- Iterates the lines of old_text deleted, in order, as: its line in old_text, its place in its hunk, and the 0-based
-- row of new_text it is drawn at. A pure deletion is drawn above the line after it.
function Diff:each_deleted_line()
    local hunks, hunk_index, index = self.hunks, 1, 0
    return function()
        local hunk = hunks[hunk_index]
        while hunk and index >= hunk.old_count do
            hunk_index, index = hunk_index + 1, 0
            hunk = hunks[hunk_index]
        end
        if not hunk then
            return nil
        end
        index = index + 1
        local row = hunk.new_count > 0 and hunk.new_start - 1 or hunk.new_start
        return hunk.old_start + index - 1, index, row
    end
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
