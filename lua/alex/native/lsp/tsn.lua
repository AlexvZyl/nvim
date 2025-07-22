local LU = require("lspconfig.util")
local U = require("alex.utils")

if not U.in_home_dir("TSN") then
    return
end

local SCRIPT_FILE = "docker_image_runner.sh"
local TIMEOUT_MS = 100

local function get_lsp_command()
    -- Give everything some time to startup before we try to push
    -- the notification.
    local curr_dir = U.current_dir_abs()

    -- TODO: Why is this not working?
    local docker_path = vim.fn.finddir("docker", ".;")
    if string.find(curr_dir, "tsnsystems_utils") then
        docker_path = vim.fn.finddir("./docker", ".;")
    end

    -- Could not find docker.
    if not docker_path or docker_path == "" then
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
    if string.find(curr_dir, "tsnsystems_utils") then
    elseif string.find(curr_dir, "analysis/box4") then
        dockerfile = vim.fn.finddir("Dockerfiles", ".;") .. "/box4dev"
        map_dest = "/app/dev/analysis"
    end

    local compile_commands_dir = map_dest .. curr_dir:gsub(git_root, "")
    local cmd = {
        docker_path .. "/" .. SCRIPT_FILE,
        dockerfile,
        "--lsp",
        "clangd",
        "--background-index",
        "--path-mappings=" .. map_source .. "=" .. map_dest,
        "--compile-commands-dir=" .. compile_commands_dir,
    }

    vim.defer_fn(function()
        vim.notify(vim.inspect(cmd))
    end, TIMEOUT_MS)
    return cmd
end

vim.lsp.config("clangd", {
    cmd = get_lsp_command(),
})

-- TODO: Get this working with the TSN dockerfiles.
vim.lsp.config("dockerls", {
    root_dir = LU.root_pattern({
        "[dD]ockerfile*",
    }),
})
