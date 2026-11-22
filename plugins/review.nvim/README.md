# review.nvim

Review the current branch against a base ref (default `dev`).

```sh
nvim diff [ref]
```

- `require("review").panel()`: Toggle the file panel.  `<CR>` opens, `d` marks reviewed, `u` / `<C-r>` undo/redo.
- `require("review").files(opts)`: Telescope picker over the changed files.
- `]h` / `[h`: Jump between hunks.
- `:ReviewReset`: Clear the review state.

Needs `nvim-web-devicons`, and `telescope.nvim` for `files()`.  Set the `Review*` highlight groups yourself.
