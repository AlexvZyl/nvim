local U = require("alex.utils.lua")
if not U.in_home_dir("TSN") and not U.in_dir("/app") then return end

local LU = require("lspconfig.util")
local LC = require("lspconfig")
local C = require("alex.plugins.lang.lsp.config")

local function get_docker_script()
    local possible_dirs = { "/docker", "../docker", "../../docker" }
    local curr_dir = U.current_dir()

    for _, dir in ipairs(possible_dirs) do
        local script = curr_dir .. dir .. "/docker_image_runner.sh"
        if U.file_exists(script) then return script end
    end

    vim.notify("Could not find TSN docker script for lsp", "ERROR")
end

LC.clangd.setup({
    lsp_flags = C.lsp_flags,
    capabilities = C.capabilities,
    cmd = {
        get_docker_script(),
        "--lsp",
        "clangd",
        "--background-index",
    },
    root_dir = LU.root_pattern(
        ".clangd",
        ".clang-tidy",
        ".clang-format",
        "compile_commands.json",
        "compile_flags.txt",
        "configure.ac",
        ".git"
    ),
})
