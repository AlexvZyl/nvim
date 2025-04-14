local U = require("alex.utils")
if not U.in_home_dir("TSN") and not U.in_dir("/app") then
    return
end

local SCRIPT_FILE = "docker_image_runner.sh"

local function get_docker_path()
    -- TODO: Use vim.fn.finddir
    local possible_dirs = { "/docker", "/../docker", "/../../docker" }
    local curr_dir = U.current_dir_abs()

    for _, dir in ipairs(possible_dirs) do
        local script_abs = curr_dir .. dir .. "/" .. SCRIPT_FILE
        if U.file_exists(script_abs) then
            return curr_dir .. dir
        end
    end

    return nil
end

local function get_lsp_command()
    local docker_path = get_docker_path()
    local timeout_ms = 150
    local curr_dir = U.current_dir_abs()

    if not docker_path then
        vim.defer_fn(function()
            vim.notify("Could not find TSN docker script for lsp", "WARN")
        end, timeout_ms)
        return
    else
        vim.defer_fn(function()
            vim.notify('Using docker @ "' .. docker_path .. '/"', "INFO")
        end, timeout_ms)
    end

    -- Git root.
    local git_root = U.get_git_root()
    if not git_root then
        vim.defer_fn(function()
            vim.notify('Could not find git root for :"' .. curr_dir .. '"')
        end, timeout_ms)
        return
    end

    local dockerfile_path = docker_path .. "/Dockerfile.base"
    local map_source = git_root
    local map_dest = "/app/dev"
    local comp_cmds_dir = map_dest .. curr_dir:gsub(git_root, "")

    -- Determine dockerfile.
    -- TODO: This should check for the git root name.
    if string.find(curr_dir, "tsnsystems_utils") then
        dockerfile_path = docker_path .. "/Dockerfile.base"
    elseif string.find(curr_dir, "analysis") then
        dockerfile_path = docker_path .. "/../docker.configs/Dockerfile.box4dev"
    end

    return {
        docker_path .. "/" .. SCRIPT_FILE,
        dockerfile_path,
        "--lsp",
        "clangd",
        "--background-index",
        "--path-mappings=" .. map_source .. "=" .. map_dest,
        "--compile-commands-dir=" .. comp_cmds_dir,
    }
end

vim.lsp.config("clangd", {
    cmd = get_lsp_command(),
})
