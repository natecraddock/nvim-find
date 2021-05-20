# nvim-find

A simple plugin to help find files quickly and accurately.

## Features

* Unique non-fuzzy file-finding algorithm optimized for matching file names.
* Caches the file list index for faster searching.
* Simple, fast, and focused. Tries to not break flow with a fancy UI.

## Why nvim-find over Telescope?

After settling on Neovim as a text editor I found myself trying all of the many file-finding plugins
(fzf, clap, telescope, ctrlp, etc.) but none fit my exact needs.

After doing some [research](https://nathancraddock.com/posts/in-search-of-a-better-finder/) on file
finding, I decided to create a plugin that fit my needs, including a custom-designed algorigthm optimized
for finding files.

[Telescope](https://github.com/nvim-telescope/telescope.nvim) is a fantastic plugin and is far more
feature-complete and extensible than nvim-find. If you are looking for a finder with many features like
fuzzy-search, previews, chaining, and a fancy UI, Telescope is probably a better fit for you.

## Installation

**Requires Neovim >= v0.5.0**

Install with a plugin manager such as:

[vim-plug](https://github.com/junegunn/vim-plug)

```
Plug 'natecraddock/nvim-find'
```

[packer](https://github.com/wbthomason/packer.nvim)

```
use 'natecraddock/nvim-find'
```

If you think instructions for another plugin manager should be listed, please send a pull request!

## Usage

To open the finder you need to configure a mapping, here is an example to bind to <kbd>ctrl p</kbd>
in normal mode.

```
nnoremap <silent> <c-p> :lua require("nvim-find").files()<cr>
```

The command `:NvimFindFiles` is also available.

Once the popup is open there are some default mappings enabled:

Key(s) | Mapping
-------|--------
<kbd>ctrl-j</kbd> or <kbd>ctrl-n</kbd> | down
<kbd>ctrl-k</kbd> or <kbd>ctrl-p</kbd> | up
<kbd>enter</kbd>  | open file in last buffer
<kbd>ctrl-v</kbd> | split vertically and open
<kbd>ctrl-s</kbd> | split horizontally and open

Any of <kbd>esc</kbd>, <kbd>ctrl-[</kbd> and <kbd>ctrl-c</kbd> will close the finder immediately.

## File Finding Algorithm

## Roadmap

## Contributing
If you find a bug, have an idea for a new feature, or even write some code you want included, please
create an issue or pull request! I would appreciate contributions. Note that plan to keep nvim-find
simple, focused, and opinionated, so not all features will be accepted.
