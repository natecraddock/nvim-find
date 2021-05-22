# nvim-find

A fast and simple finder plugin for Neovim

## Goals

* **Speed:** The finder should open fast and filter quickly
* **Simplicity:** The finder should be unobtrusive and not distract from flow
  * insert mode only
  * simple ui
  * no previews
* **Extensible:** It should be easy to create custom finders

## Included Finders

For usage instructions see the [Finders](#finders) section below.

* **Files:** Find files in the current working directory

## Requirements

**Requires Neovim >= v0.5.0**

Optional dependencies:
* [`fd`](https://github.com/sharkdp/fd) for listing files. If not installed nvim-find will use a file finder
written in Lua, which is nearly as fast, but does not have a complete .gitignore implementation.

## Installation

Install with a plugin manager such as:

[vim-plug](https://github.com/junegunn/vim-plug)

```
Plug 'natecraddock/nvim-find'
```

[packer](https://github.com/wbthomason/packer.nvim)

```
use 'natecraddock/nvim-find'
```

# Finders

Finders are not mapped by default. Each section below indicates which function to map to enable
quick access to the finder. The default command is also listed if available.

## General

These mappings are enabled when a finder is open

Key(s) | Mapping
-------|--------
<kbd>ctrl-j</kbd> or <kbd>ctrl-n</kbd> | select next file
<kbd>ctrl-k</kbd> or <kbd>ctrl-p</kbd> | select previous file
<kbd>esc</kbd>, <kbd>ctrl-[</kbd> or <kbd>ctrl-c</kbd> | close finder

## Files
Find files in the current working directory.

Because the [majority of file names are unique](https://nathancraddock.com/posts/in-search-of-a-better-finder/)
within a project, the file finder does not do fuzzy-matching. The query is separated into space-delimited tokens.
Each token is used to filter the file list by file name. Then each token is used again to further reduce the list
of results by matching against the full file paths.

Although this finder does not do fuzzy-matching, there is still some degree of sloppiness allowed. If the characters
`-_.` are not included in the query they will be ignored in the file paths. For example, the query
`outlinerdrawc` matches the file `outliner_draw.c`.

The list of files is cached in an index for faster filtering. If any files in the project are added, moved, or deleted,
the index will automatically update in the background.

Example mapping:
```
nnoremap <silent> <c-p> :lua require("nvim-find").files()<cr>
```

**Command:** `:NvimFindFiles`

Key | Mapping
----|--------
<kbd>enter</kbd>  | open selected file in last used buffer
<kbd>ctrl-v</kbd> | split vertically and open selected file
<kbd>ctrl-s</kbd> | split horizontally and open selected file
<kbd>ctrl-t</kbd> | open selected file in a new tab

# Roadmap

Although I plan to keep nvim-find smaller in scope than similar plugins, there are still a number of improvements
I have planned including:
* More built-in finders:
  * rg/ag/grep search
  * buffers
  * commands
* Result sorting
* Improved performance for large projects (more than 100,000 files)
* Documentation
* Customization
* Visual improvements

# Contributing
If you find a bug, have an idea for a new feature, or even write some code you want included, please
create an issue or pull request! I would appreciate contributions. Note that plan to keep nvim-find
simple, focused, and opinionated, so not all features will be accepted.
