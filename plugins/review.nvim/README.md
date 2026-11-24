# review.nvim

Review the current branch against a base ref, in place.

## Setup

```lua
require("review").setup({
    base = "dev",
    width = 60,
    depth = 2,
    sign_priority = 6,
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
```

## Commands

| Command | Function | Does |
|---|---|---|
| | `require("review").setup(opts)` | Sets up the commands and keymaps. |
| `:Review [ref]` | `require("review").start(ref)` | Starts or switches the review and opens the panel. |
| `:ReviewStop` | `require("review").stop()` | Stops reviewing. |
| `:ReviewReset` | `require("review").reset()` | Forgets which files were reviewed. |
| | `require("review").panel()` | Toggles the panel. |
| `:Telescope review` | `require("review").files(opts)` | Picks a changed file. |
| | `require("review").active()` | Whether a review is running. |
