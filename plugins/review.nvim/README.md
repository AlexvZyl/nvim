# review.nvim

Review the current branch against a base ref (default `dev`).

```sh
nvim diff [ref]
```

- `require("review").setup(opts)`: Defaults and keymaps are in [config.lua](lua/review/config.lua).
- `require("review").panel()`: Toggle the file panel.  `<CR>` opens, `d` marks reviewed, `u` / `<C-r>` undo/redo.
- `]h` / `[h`: Jump between hunks.
- `:ReviewReset`: Clear the review state.
