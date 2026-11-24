local M = {}

-- Not installed in CI.
package.preload["nvim-web-devicons"] = function()
    return {
        get_icon = function()
            return "", "Normal"
        end,
    }
end

local function git(dir, ...)
    local result = vim.system({ "git", "-C", dir, ... }, { text = true }):wait()
    assert(result.code == 0, table.concat({ ... }, " ") .. ": " .. (result.stderr or ""))
    return result.stdout
end

-- Writes the lines, or a string as it is, making the directories it is in.
function M.write(path, content)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    if type(content) == "table" then
        return vim.fn.writefile(content, path)
    end
    local file = assert(io.open(path, "wb"))
    file:write(content)
    file:close()
end

-- Lines "line 1" to "line n".
function M.lines(n)
    local lines = {}
    for i = 1, n do
        lines[i] = "line " .. i
    end
    return lines
end

-- Runs git in the cwd.
function M.git(...)
    return git(vim.fn.getcwd(), ...)
end

-- Writes the files, by their path, and commits them.
function M.commit(files)
    for path, content in pairs(files) do
        M.write(path, content)
    end
    M.git("add", ".")
    M.git("commit", "-qm", "files")
end

-- A copy of the lines with the changes by line number: replaced by a line or lines, or deleted by false.
function M.edit(lines, changes)
    local edited = {}
    for i, line in ipairs(lines) do
        local change = changes[i]
        if type(change) == "table" then
            vim.list_extend(edited, change)
        elseif change ~= false then
            table.insert(edited, change or line)
        end
    end
    return edited
end

-- A repo with `file` at `base` on dev, `committed` on a branch from it and `working` uncommitted, in the cwd.
function M.repo(base, committed, working)
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    git(dir, "init", "-q", "-b", "dev")
    git(dir, "config", "user.email", "test@test")
    git(dir, "config", "user.name", "test")
    M.write(dir .. "/file.txt", base)
    git(dir, "add", ".")
    git(dir, "commit", "-qm", "base")
    git(dir, "checkout", "-qb", "branch")
    M.write(dir .. "/file.txt", committed)
    git(dir, "commit", "-qam", "committed", "--allow-empty")
    M.write(dir .. "/file.txt", working or committed)
    vim.cmd.cd(dir)
    return dir
end

-- Opens the file in a fixed size window, reviewed against dev and rendered.
function M.open()
    vim.o.lines = 50
    vim.o.columns = 200
    vim.cmd("silent! %bwipeout!")
    assert(require("review.session").start("dev"))
    vim.cmd.edit("file.txt")
    local buf = vim.api.nvim_get_current_buf()
    require("review.render").attach(buf)
    M.flush()
    return buf
end

-- Starts the review from scratch, as a session left by open() would keep it from setting up.
function M.start()
    require("review").stop()
    require("review").start("dev")
end

-- Starts the review in a fixed size window, focusing the panel, or the window next to it with the file opened.
-- Returns the window, the panel and its buffer.
function M.review(file)
    vim.o.lines = 40
    vim.o.columns = 200
    vim.cmd("silent! only | enew | silent! %bwipeout!")
    local main = vim.api.nvim_get_current_win()
    M.start()
    local panel, panel_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    if file then
        vim.api.nvim_set_current_win(main)
        vim.cmd.edit(file)
    end
    return main, panel, panel_buf
end

-- Types the keys, mapped like a person typing them.
function M.press(keys)
    vim.api.nvim_feedkeys(vim.keycode(keys), "x", false)
end

-- Opens the file from the panel, focused, by the end of its name.
function M.pick(name)
    vim.fn.cursor(vim.fn.search(name .. "$"), 1)
    M.press("<CR>")
end

-- Runs the scheduled render and redraws, like the main loop between keys.
function M.flush()
    -- The main loop redraws before it waits for keys, which is when scheduled callbacks run.
    vim.cmd("redraw")
    vim.wait(1, function()
        return false
    end)
    vim.cmd("redraw")
end

-- Runs normal mode keys like typed, with the render after TextChanged and SafeState once it settles. Without
-- settle, like keys typed faster than the screen settles.
function M.keys(keys, settle)
    local render = require("review.render")
    vim.cmd("silent normal! " .. keys)
    vim.cmd("redraw")
    render.update(vim.api.nvim_get_current_buf())
    M.flush()
    if settle ~= false then
        render.settled()
    end
end

-- Puts the cursor on the line, the given number of lines below the top of the window.
function M.place(line, offset)
    vim.cmd(("normal! %dGzt%dG"):format(math.max(line - offset, 1), line))
    vim.cmd("redraw")
    require("review.render").settled()
end

function M.view()
    local view = vim.fn.winsaveview()
    return { top = view.topline, fill = view.topfill, line = view.lnum, row = vim.fn.winline() }
end

-- Extmarks of a review namespace from the line, with their details.
function M.marks(buf, namespace, first, last)
    local id = vim.api.nvim_create_namespace(namespace)
    return vim.api.nvim_buf_get_extmarks(buf, id, { first - 1, 0 }, { last - 1, 0 }, { details = true })
end

-- The text of the virtual lines of a mark, without the number and sign columns, and the sign of each.
function M.virt_lines(mark)
    local lines = {}
    for _, chunks in ipairs(mark[4].virt_lines or {}) do
        local text = {}
        for i = 3, #chunks do
            table.insert(text, chunks[i][1])
        end
        table.insert(lines, { text = vim.trim(table.concat(text)), sign = vim.trim(chunks[2][1]), group = chunks[2][2] })
    end
    return lines
end

return M
