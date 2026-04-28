local U = require("alex.utils")

-- WARN:  Check the commit timestamp for when this was setup.  While I was working at TSN the
-- docker stuff changed quite a bit, I have no idea how stable this config will be.
--
-- This also uses utils from the rest of my config.  Might have to copy them.
--
-- Goodluck ;)

-- I only want this config to run for stuff in "~/TSN/*".
if not U.in_home_dir("TSN") then
    return
end

local SCRIPT_FILE = "docker_image_runner.sh"
local TIMEOUT_MS = 100

local function is_repo(repo)
    local git_root = U.get_git_root()
    if not git_root then
        return false
    end
    local basename = vim.fn.fnamemodify(git_root, ":t")
    return basename == repo
end

local function get_lsp_command()
    local curr_dir = U.current_dir_abs()

    -- Docker repository is always placed in root of repo.
    -- WARN: This will fail if neovim is not opened in the root.
    local docker_path = "./docker"

    -- Could not find docker.
    if vim.fn.isdirectory(docker_path) == 0 then
        vim.defer_fn(function()
            vim.notify("Could not find TSN docker path", vim.log.levels.WARN)
        end, TIMEOUT_MS)
        return
    end

    -- Git root.
    local git_root = U.get_git_root()
    if not git_root then
        vim.defer_fn(function()
            vim.notify('Could not find git root for :"' .. curr_dir .. '"')
        end, TIMEOUT_MS)
        return
    end

    -- Defaults.
    local dockerfile = docker_path .. "/Dockerfiles/base"
    local map_source = git_root
    local map_dest = "/app/dev"

    -- Custom config (not all repos have the same setup)
    if is_repo("box4") then
        dockerfile = git_root .. "/Dockerfiles/box4dev"
        map_dest = "/app/dev/box4"
    end

    -- NOTE: Depending on how you setup the repos this might break.  I always linked the compile commands
    -- file to one in the root of the dirrectory.  A bit manual but it works.
    local compile_commands_dir = map_dest .. curr_dir:gsub(git_root, "")
    local cmd = {
        "env",
        -- NOTE: This is important.  The default script args do not work.
        "RUN_ARGS=-i",
        docker_path .. "/" .. SCRIPT_FILE,
        dockerfile,
        "clangd",
        "--background-index",
        -- NOTE: Because I use NixOS this causes jumping to system source files to not
        -- work (NixOS does not use a posix filesystem).  Mileage may vary.
        "--path-mappings=" .. map_source .. "=" .. map_dest,
        "--compile-commands-dir=" .. compile_commands_dir,
    }

    -- Displays this at runtime to:
    -- 1. Show me this actually ran.
    -- 2. Allows me to easily debug if something in the command seems off.
    vim.defer_fn(function()
        vim.notify(vim.inspect(cmd))
    end, TIMEOUT_MS)
    return cmd
end

vim.lsp.config("clangd", {
    cmd = get_lsp_command(),
})

vim.lsp.enable("clangd")

-- Get the docker lsp running with the TSN dockerfiles.

vim.filetype.add({
    pattern = {
        [".*/Dockerfiles/[^.]+"] = "dockerfile",
    },
})

vim.lsp.config("dockerls", {
    filetypes = { "dockerfile" },
})

vim.lsp.enable("dockerls")
