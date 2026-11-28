-- Drawing helpers shared by buffers, deleted files and diagnostics.
local config = require("review.config")

local M = {}

M.namespace = vim.api.nvim_create_namespace("review")

-- By group name. Marks take ids faster than names.
local hl_ids = setmetatable({}, {
    __index = function(ids, name)
        ids[name] = vim.api.nvim_get_hl_id_by_name(name)
        return ids[name]
    end,
})

local function sign_text(uncommitted)
    return config.options.signs[uncommitted and "uncommitted" or "committed"]
end

-- Kind is Add or Delete.
function M.sign(buf, first_line, last_line, uncommitted, kind)
    local group = "Review" .. (uncommitted and "Local" or "") .. kind
    vim.api.nvim_buf_set_extmark(buf, M.namespace, first_line - 1, 0, {
        end_row = last_line - 1,
        line_hl_group = group,
        number_hl_group = group .. "Nr",
        sign_text = sign_text(uncommitted),
        sign_hl_group = "ReviewSign" .. group:sub(7),
        priority = config.options.sign_priority,
    })
end

-- The number and sign columns as chunks, for virtual lines.
function M.gutter(gutter_width, uncommitted, kind)
    local text = sign_text(uncommitted)
    local sign = text .. string.rep(" ", gutter_width - 1 - vim.fn.strdisplaywidth(text))
    return { { " ", hl_ids.LineNr }, { sign, hl_ids["ReviewSign" .. (uncommitted and "Local" or "") .. kind] } }
end

-- A deleted line as chunks: highlighted by byte, scrolled by leftcol and padded to the window's edge.
function M.deleted_line(text, highlights, uncommitted, leftcol, tabstop)
    local group = uncommitted and "ReviewLocalDelete" or "ReviewDelete"
    local line_id, background_id = hl_ids[group], hl_ids[group .. "Background"]
    local chunks, width, last_group = {}, 0, nil
    -- Merges neighbours with the same highlight.
    local function add(part, part_group)
        if chunks[1] and part_group == last_group then
            chunks[#chunks][1] = chunks[#chunks][1] .. part
        else
            table.insert(chunks, { part, part_group and { line_id, hl_ids[part_group], background_id } or line_id })
        end
        last_group = part_group
    end
    -- Start of the current run of visible bytes. A byte loop, as the JIT does not compile gmatch.
    local run_start, byte = nil, 1
    while byte <= #text do
        local byte_group, code = highlights[byte], text:byte(byte)
        -- Skips UTF-8 continuation bytes.
        local next_char = byte + 1
        while (text:byte(next_char) or 0) >= 128 and text:byte(next_char) < 192 do
            next_char = next_char + 1
        end
        local cells = code == 9 and tabstop - width % tabstop
            or code < 128 and 1
            or vim.api.nvim_strwidth(text:sub(byte, next_char - 1))
        width = width + cells
        local visible_cells = math.min(cells, width - leftcol)
        -- Tabs, and wide characters cut by the window edge (as <), are drawn as blanks.
        local blank = visible_cells > 0 and (code == 9 or visible_cells < cells)
        if run_start and (blank or byte_group ~= highlights[run_start]) then
            add(text:sub(run_start, byte - 1), highlights[run_start])
            run_start = nil
        end
        if blank then
            add(code == 9 and string.rep(" ", visible_cells) or "<" .. string.rep(" ", visible_cells - 1), byte_group)
        elseif visible_cells > 0 then
            run_start = run_start or byte
        end
        byte = next_char
    end
    if run_start then
        add(text:sub(run_start), highlights[run_start])
    end
    table.insert(chunks, { string.rep(" ", math.max(vim.o.columns - width + leftcol, 0)), line_id })
    return chunks
end

return M
