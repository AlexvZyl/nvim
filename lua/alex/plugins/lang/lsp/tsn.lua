local U = require("alex.utils.lua")
if not U.in_home_dir("TSN") and not U.in_dir("/app") then return end

local LU = require("lspconfig.util")
local LC = require("lspconfig")
local C = require("alex.plugins.lang.lsp.config")

local script_file = "docker_image_runner.sh"

local function get_docker_path()
    local possible_dirs = { "/docker", "/../docker", "/../../docker" }
    local curr_dir = U.current_dir_abs()

    for _, dir in ipairs(possible_dirs) do
        local script_abs = curr_dir .. dir .. "/" .. script_file
        if U.file_exists(script_abs) then return curr_dir .. dir end
    end

    return nil
end

local function get_lsp_command()
    local docker_path = get_docker_path()
    if not docker_path then
        -- TODO: This is not working.
        vim.defer_fn(function() vim.notify("Could not find TSN docker script for lsp", "WARN") end, 150)
        return
    end

    local repos = { "tsnsystems_utils" }
    local curr_dir = U.current_dir_abs()
    for _, repo in ipairs(repos) do
        if string.find(curr_dir, "tsnsystems_utils") then
            return {
                docker_path .. "/" .. script_file,
                docker_path .. "/../docker.configs/" .. "Dockerfile." .. repo,
                "--lsp",
                "clangd",
                "--background-index",
                "--path-mappings",
                curr_dir .. "=/app/dev",
            }
        end
    end

    -- Default.
    return {
        docker_path .. "/" .. script_file,
        docker_path .. "/../docker.configs/" .. "Dockerfile.box4pc",
        "--lsp",
        "clangd",
        "--background-index",
        "--path-mappings",
        curr_dir .. "=/app/dev",
    }
end

LC.clangd.setup({
    lsp_flags = C.lsp_flags,
    capabilities = C.capabilities,
    cmd = get_lsp_command(),
    root_dir = LU.root_pattern("compile_commands.json"),
})
