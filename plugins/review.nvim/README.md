# review.nvim

Review the current branch against a base ref (default `dev`).

```sh
nvim diff [ref]
```

- `require("review").panel()`: Toggle the file panel.  `<CR>` opens, `d` marks reviewed, `u` / `<C-r>` undo/redo.
- `require("review").files(opts)`: Telescope picker over the changed files.
- `]h` / `[h`: Jump between hunks.
- `:ReviewReset`: Clear the review state.

Set the `Review*` highlight groups yourself.
