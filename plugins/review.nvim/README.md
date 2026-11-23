# review.nvim

Review the current branch against a base ref (default `dev`).  Requires [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) and [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons).

- `:Review [ref]`: Start reviewing, or switch to another ref, and open the panel.  Fires `User ReviewStart`.
- `:ReviewStop`: Stop reviewing.  Fires `User ReviewStop`.
- `require("review").setup(opts)`: Defaults and keymaps are in [config.lua](lua/review/config.lua).
- `require("review").panel()`: Toggle the file panel.  `<CR>` opens, `d` marks reviewed, `u` / `<C-r>` undo/redo.
- `require("review").files()` / `:Telescope review`: Pick a changed file with Telescope, mapped to `fg` (`keymaps.files`, `false` to unmap).  Configure it with `extensions.review` in the telescope setup and load it with `require("telescope").load_extension("review")`.
- `]h` / `[h`: Jump between hunks.
- Committed changes are highlighted with `ReviewAdd` / `ReviewDelete`, uncommitted ones with `ReviewLocal` and a `ReviewSignLocal` sign.
- `:ReviewReset`: Clear the review state.
