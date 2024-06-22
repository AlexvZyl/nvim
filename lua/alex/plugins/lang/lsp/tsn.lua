local U = require("alex.utils.lua")
if not U.in_home_dir("TSN") then
    return
end

local LU = require("lspconfig.util")
local LC = require("lspconfig")
local DC = require("cmp_nvim_lsp").default_capabilities()

local lsp_flags = {
    debounce_text_changes = 250, -- ms
}

local home = vim.loop.os_homedir()

LC.clangd.setup({
    lsp_flags = lsp_flags,
    capabilities = DC,
    cmd = {
        home .. "/TSN/Repos/analysis/docker/docker_image_runner.sh",
        home .. "/TSN/Repos/analysis/docker/Dockerfile.box4dev",
        "--lsp",
        "clangd",
    },
    root_dir = LU.root_pattern(
        ".clangd",
        ".clang-tidy",
        ".clang-format",
        "*compile_commands.json",
        "compile_flags.txt",
        "configure.ac",
        ".git"
    ),
})
