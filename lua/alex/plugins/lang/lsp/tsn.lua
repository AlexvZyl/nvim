local U = require("alex.utils")

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

    local suffix = "box4dev"

    local repos = {
        "tsnsystems_ipc",
        "tsnsystems_utils",
    }
    local curr_dir = U.current_dir_abs()
    for _, repo in ipairs(repos) do
        if string.find(curr_dir, repo) then suffix = repo end
    end

    return {
        docker_path .. "/" .. script_file,
        docker_path .. "/../docker.configs/" .. "Dockerfile." .. suffix,
        "--lsp",
        "clangd",
        "--background-index",
        "--path-mappings=" .. U.get_git_root():gsub("/$", "") .. "=/app/dev",
    }
end

LC.clangd.setup({
    lsp_flags = C.lsp_flags,
    capabilities = C.capabilities,
    cmd = get_lsp_command(),
    root_dir = LU.root_pattern("compile_commands.json"),
})
