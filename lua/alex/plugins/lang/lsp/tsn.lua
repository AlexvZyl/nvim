local U = require("alex.utils")
if not U.in_home_dir("TSN") and not U.in_dir("/app") then return end

local LU = require("lspconfig.util")
local LC = require("lspconfig")
local C = require("alex.plugins.lang.lsp.config")

local SCRIPT_FILE = "docker_image_runner.sh"

local function get_docker_path()
    -- TODO: Check this iteratively.
    local possible_dirs = { "/docker", "/../docker", "/../../docker" }
    local curr_dir = U.current_dir_abs()

    for _, dir in ipairs(possible_dirs) do
        local script_abs = curr_dir .. dir .. "/" .. SCRIPT_FILE
        if U.file_exists(script_abs) then return curr_dir .. dir end
    end

    return nil
end

local function get_lsp_command()
    local docker_path = get_docker_path()
    local timeout_ms = 150
    if not docker_path then
        vim.defer_fn(
            function() vim.notify("Could not find TSN docker script for lsp", "WARN") end,
            timeout_ms
        )
        return
    else
        vim.defer_fn(
            function() vim.notify('Using docker @ "' .. docker_path .. '/"', "INFO") end,
            timeout_ms
        )
    end

    -- Determine dockerfile.
    local dockerfile_path = nil
    --- TODO: This is technically not correct.
    local curr_dir = U.current_dir_abs()
    if string.find(curr_dir, "analysis") then
        dockerfile_path = docker_path .. "/../docker.configs/Dockerfile.box4dev"
    elseif string.find(curr_dir, "tsnsystems_utils") then
        dockerfile_path = docker_path .. "/Dockerfile.base"
    end

    local git_root = U.get_git_root()
    local docker_work_dir = "/app/dev"
    local compile_commands_dir = U.current_dir_abs():gsub(git_root, "")

    return {
        docker_path .. "/" .. SCRIPT_FILE,
        dockerfile_path,
        "--lsp",
        "clangd",
        "--background-index",
        "--path-mappings=" .. git_root:gsub("/$", "") .. "=" .. docker_work_dir,
        "--compile-commands-dir=" .. docker_work_dir .. "/" .. compile_commands_dir,
    }
end

LC.clangd.setup({
    lsp_flags = C.lsp_flags,
    capabilities = C.capabilities,
    cmd = get_lsp_command(),
    root_dir = LU.root_pattern("compile_commands.json"),
})
