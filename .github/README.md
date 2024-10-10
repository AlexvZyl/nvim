# "${HOME}/.config/nvim"

Configuration files and custom modules for Neovim.  This is a submodule for my [Linux](https://github.com/AlexvZyl/.dotfiles) dotfiles.

I do not use a distro becuase:
1. They are fragile.
2. I like doing things myself.

## Some notes

- I am on an endeavour to reduce the surface of `lua/alex/plugins` as much as possible, and replace it with custom stuff in `lua/alex/native` (within reason, of course).
- I am not setting up my packages in the way that is described by `lazy.nvim`.  I am trying to keep my configs "package manager agnostic" as far as possible.
- I try to keep all of the key bindings in [one file](https://github.com/AlexvZyl/nvim/blob/main/lua/alex/keymaps/init.lua) so that it is easier to keep track of everything and prevent conflicts.
- You can add more LSPs to the end of [this file](https://github.com/AlexvZyl/nvim/blob/main/lua/alex/plugins/lang/lsp/init.lua).

![image](https://github.com/user-attachments/assets/a30fa532-6054-4ad7-ba3f-34e257c39c58)
