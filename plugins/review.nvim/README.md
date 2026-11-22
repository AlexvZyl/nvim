# review.nvim

Review the current branch against a base ref (default `dev`).

```sh
nvim diff [ref]
```

- `require("review").setup({ base = "dev", width = 60, depth = 2 })`: The defaults, `depth` is the directory levels the panel groups by.
- `require("review").panel()`: Toggle the file panel.  `<CR>` opens, `d` marks reviewed, `u` / `<C-r>` undo/redo.
- `]h` / `[h`: Jump between hunks.
- `:ReviewReset`: Clear the review state.
