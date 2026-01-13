local LU = require("lspconfig.util")
local U = require("alex.utils")

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

    -- NOTE: This should hold in all cases.
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

    -- TODO: Try to finish this.
    -- local nix_std_include
    -- local handle = io.popen("nix eval --raw nixpkgs#linuxHeaders")
    -- if handle then
    --     local dir = handle:read("*a")
    --     handle:close()
    --     nix_std_include = dir:gsub("\n", "") .. "/include"
    -- else
    --     vim.defer_fn(function()
    --         vim.notify("Could not get nix std lib location")
    --     end, TIMEOUT_MS)
    --     return
    -- end

    -- Defaults.
    local dockerfile = docker_path .. "/Dockerfiles/base"
    local map_source = git_root
    local map_dest = "/app/dev"

    -- Custom config (not all repos have the same setup)
    if is_repo("box4") then
        dockerfile = git_root .. "/Dockerfiles/box4dev"
        map_dest = "/app/dev/box4"
    end

    local compile_commands_dir = map_dest .. curr_dir:gsub(git_root, "")
    local cmd = {
        docker_path .. "/" .. SCRIPT_FILE,
        dockerfile,
        "--lsp",
        "clangd",
        "--background-index",
        "--path-mappings=" .. map_source .. "=" .. map_dest,
        -- "--path-mappings=" .. map_source .. "=" .. map_dest .. "," .. nix_std_include .. "=" .. "/usr/include",
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
