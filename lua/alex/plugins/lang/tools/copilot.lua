require('copilot').setup {
    panel = { enabled = false },
    suggestion = {
        enabled = true,
        auto_trigger = true,
        accept = false,
        debounce = 200,
        keymap = { accept = '<C-a>', dismiss = '<C-d>' },
    },
}

-- Hide copilot suggestions when cmp menu is open to prevent odd behavior/garbled up suggestions.
local cmp = require 'cmp'
cmp.event:on(
    'menu_opened',
    function() vim.b.copilot_suggestion_hidden = true end
)
cmp.event:on(
    'menu_closed',
    function() vim.b.copilot_suggestion_hidden = false end
)

require('alex.keymaps').copilot()

vim.cmd 'Copilot disable'
