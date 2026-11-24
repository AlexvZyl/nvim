# review.nvim

Review the current branch against a base ref. Changed lines are highlighted in place, deleted lines are shown inline,
and a panel lists the changed files to mark them reviewed as you go.

Requires [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) and
[nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons).

## Setup

```lua
require("review").setup({
    -- Ref to review against when :Review is given none.
    base = "dev",
    -- Width of the panel.
    width = 60,
    -- Directory levels the panel groups files by.
    depth = 2,
    -- Of the signs, under the diagnostic signs at 10.
    sign_priority = 6,
    -- false leaves a key unmapped.
    keymaps = {
        files = "fg",
        open = "<CR>",
        review = "d",
        undo = "u",
        redo = "<C-r>",
        next_hunk = "]h",
        prev_hunk = "[h",
    },
})
require("telescope").load_extension("review")
```

The picker takes its options from `extensions.review` in the telescope setup.

## Commands

| Command | Function | Does |
|---|---|---|
| `:Review [ref]` | `require("review").start(ref)` | Starts reviewing against `ref` (default `base`), or switches to it, and opens the panel. |
| `:ReviewStop` | `require("review").stop()` | Stops reviewing. |
| `:ReviewReset` | `require("review").reset()` | Forgets which files were reviewed. |
| | `require("review").panel()` | Toggles the panel. |
| `:Telescope review` | `require("review").files(opts)` | Picks a changed file. |
| | `require("review").active()` | Whether a review is running. |

## Keymaps

| Key | Where | Does |
|---|---|---|
| `fg` | Everywhere | Picks a changed file. |
| `<CR>` | Panel | Opens the file under the cursor. |
| `d{motion}`, `dd`, `{Visual}d` | Panel | Marks files reviewed, which hides them. |
| `u` / `<C-r>` | Panel | Undoes / redoes marking files reviewed. |
| `]h` / `[h` | Changed files | Jumps to the next / previous hunk. |
