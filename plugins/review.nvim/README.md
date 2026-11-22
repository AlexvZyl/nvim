# review.nvim

Review the current branch against a base ref (default `dev`).

- `:Review [ref]`: Start reviewing, or switch to another ref, and open the panel.  Fires `User ReviewStart`.
- `:ReviewStop`: Stop reviewing.  Fires `User ReviewStop`.
- `require("review").setup(opts)`: Defaults and keymaps are in [config.lua](lua/review/config.lua).
- `require("review").panel()`: Toggle the file panel.  `<CR>` opens, `d` marks reviewed, `u` / `<C-r>` undo/redo.
- `]h` / `[h`: Jump between hunks.
- `:ReviewReset`: Clear the review state.
