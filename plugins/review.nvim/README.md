# review.nvim

Review the diff of the current branch against a base ref, file by file.

## Usage

Start neovim in diff mode, the ref defaults to `dev`:

```sh
nvim diff [ref]
```

- `require("review").panel()`: Toggle the file panel.
- `require("review").files(opts)`: Telescope picker over the changed files, `opts` is passed to `find_files`.
- `:ReviewReset`: Clear the review state for the current branch.

In the panel, `<CR>` opens a file, `d` marks files as reviewed (supports motions and visual mode), and `u` / `<C-r>` undo and redo.  In a file, `]h` and `[h` jump between hunks.

Review state is stored in `.git/review/`.

## Requirements

- `nvim-web-devicons`
- `telescope.nvim` (only for `files()`)

## Highlights

The plugin does not define any highlights, set these in your config:

`ReviewAdd`, `ReviewAddNr`, `ReviewDelete`, `ReviewSignAdd`, `ReviewSignLocal`, `ReviewSignDelete`, `ReviewPanelLine`, `ReviewPanelDir`, `ReviewPanelNr`, `ReviewChanged`, `ReviewNew`.
