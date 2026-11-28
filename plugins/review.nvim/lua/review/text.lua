-- Text is one version of a file, like at HEAD or the merge base, with its highlights cached.
local Text = {}
Text.__index = Text

-- Most lines parsed around a deleted line, for highlights that depend on surrounding code.
local CONTEXT_LINES = 30

-- Nil content means the file does not exist in this version.
function Text.new(content)
    content = content or ""
    return setmetatable({
        content = content,
        lines = vim.split(content, "\n", { plain = true }),
        -- By language, then line: the highlight group of each byte.
        highlights_by_lang = {},
        -- Lines shown as deleted, set by Buffer.
        shown_deleted = {},
    }, Text)
end

-- Hunks from this text to the other content, with the lines of this one they delete.
function Text:diff(other_content)
    local hunks = {}
    for _, hunk in ipairs(vim.text.diff(self.content, other_content, { result_type = "indices", indent_heuristic = true })) do
        local old_start, old_count, new_start, new_count = unpack(hunk)
        table.insert(hunks, {
            old_start = old_start,
            new_start = new_start,
            new_count = new_count,
            deleted_lines = vim.list_slice(self.lines, old_start, old_start + old_count - 1),
        })
    end
    return hunks
end

-- Runs of lines to highlight in one parse, as { first, last }: the line, plus with whole_file the unhighlighted
-- deleted lines chained within CONTEXT_LINES of it. Marks them highlighted.
function Text:runs(highlights, line, whole_file)
    local first, last = line, line
    if whole_file then
        local row = line - 1
        while row >= math.max(first - CONTEXT_LINES, 1) do
            first = self.shown_deleted[row] and not highlights[row] and row or first
            row = row - 1
        end
        row = line + 1
        while row <= math.min(last + CONTEXT_LINES, #self.lines) do
            last = self.shown_deleted[row] and not highlights[row] and row or last
            row = row + 1
        end
    end
    local runs = {}
    for row = first, last do
        if row == line or self.shown_deleted[row] and not highlights[row] then
            highlights[row] = {}
            local run = runs[#runs]
            if run and run[2] == row - 1 then
                run[2] = row
            else
                table.insert(runs, { row, row })
            end
        end
    end
    return runs
end

-- Parses the lines around the runs, injecting languages only in the runs. Nil without a parser.
function Text:parse(lang, runs, lines_above, lines_below)
    local first_line = math.max(runs[1][1] - lines_above, 1)
    local last_line = math.min(runs[#runs][2] + lines_below, #self.lines)
    local source = table.concat(self.lines, "\n", first_line, last_line)
    local ok, parser = pcall(vim.treesitter.get_string_parser, source, lang)
    if not ok then
        return nil
    end
    -- All at once, as parsing a range drops injections outside it.
    parser:parse(vim.tbl_map(function(run)
        return { run[1] - first_line, 0, run[2] - first_line + 1, 0 }
    end, runs))
    return { parser = parser, source = source, first_line = first_line, last_line = last_line }
end

-- Stores the tree's captures in the runs, then its injected languages', so theirs win.
local function capture(lines, highlights, parsed, tree, runs)
    local lang = tree:lang()
    local query = vim.treesitter.query.get(lang, "highlights")
    for _, root in ipairs(query and tree:trees() or {}) do
        for _, run in ipairs(runs) do
            local from_row, to_row = run[1] - parsed.first_line, run[2] - parsed.first_line
            for id, node in query:iter_captures(root:root(), parsed.source, from_row, to_row + 1) do
                local name = query.captures[id]
                if not name:find("^_") and name ~= "spell" and name ~= "nospell" then
                    local start_row, start_col, end_row, end_col = node:range()
                    for row = math.max(start_row, from_row), math.min(end_row, to_row) do
                        local line = parsed.first_line + row
                        local line_highlights = highlights[line]
                        for col = (row == start_row and start_col or 0) + 1, row == end_row and end_col or #lines[line] do
                            line_highlights[col] = "@" .. name .. "." .. lang
                        end
                    end
                end
            end
        end
    end
    for _, child in pairs(tree:children()) do
        capture(lines, highlights, parsed, child, runs)
    end
end

-- The highlight group of each byte of the line. Nearby deleted lines are highlighted in the same parse. Parses at
-- most CONTEXT_LINES around them, or fewer lines above and below when given, like a code block's.
function Text:highlight(lang, line, lines_above, lines_below)
    self.highlights_by_lang[lang] = self.highlights_by_lang[lang] or {}
    local highlights = self.highlights_by_lang[lang]
    if highlights[line] then
        return highlights[line]
    end
    local whole_file = lines_above == math.huge and lines_below == math.huge
    local runs = self:runs(highlights, line, whole_file)
    local parsed = self:parse(lang, runs, math.min(lines_above, CONTEXT_LINES), math.min(lines_below, CONTEXT_LINES))
    if not parsed then
        return highlights[line]
    end
    -- Code opened outside the parsed lines, like an XML root tag, leaves them in errors.
    local first, last = runs[1][1], runs[#runs][2]
    local cut_short = parsed.first_line > math.max(first - lines_above, 1)
        or parsed.last_line < math.min(last + lines_below, #self.lines)
    if cut_short and parsed.parser:trees()[1]:root():has_error() then
        parsed = self:parse(lang, runs, lines_above, lines_below) or parsed
    end
    capture(self.lines, highlights, parsed, parsed.parser, runs)
    return highlights[line]
end

return Text
