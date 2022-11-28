# Notice

I am no longer maintaining this plugin. To my knowledge, it still
functions perfectly fine as a simple fuzzy finder interface for neovim.

When I first wrote nvim-find, I wanted a better fuzzy-finder matching
experience in neovim, because I'm not perfectly happy with fzf or fzy's
algorithms. So I made this plugin.

Later, after [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
fixed a few missing features, I realized it would be a better use of my time to
use telescope for my fuzzy finder interface, and make my own algorithm to be
used in telescope and in the terminal.

So I have created [zf](https://github.com/natecraddock/zf) as a replacement to fzf
and fzy, and [telescope-zf-native.nvim](https://github.com/natecraddock/telescope-zf-native.nvim)
to integrate zf with telescope. This means I don't have to maintain a fuzzy finding
interface _and_ a sorting algorithm.

So you are welcome to use this, but I would recommend using telescope and zf
if you want to have a filename matching algorithm similar to nvim-find.

# nvim-find

A fast and simple finder plugin for Neovim

## Goals

* **Speed:** The finder should open fast and filter quickly
* **Simplicity:** The finder should be unobtrusive and not distract from flow
* **Extensible:** It should be easy to create custom finders

## Default Finders

For usage instructions see the [Finders](#finders) section below.

* **Files:** Find files in the current working directory respecting gitignore
* **Buffers:** List open buffers
* **Search:** Search using ripgrep in the current working directory

## Requirements

**Requires Neovim >= v0.5.0**

Optional dependencies:
* [`fd`](https://github.com/sharkdp/fd) for listing files.
* [`ripgrep`](https://github.com/BurntSushi/ripgrep) for listing files or for project search.
  `ripgrep` may be used in place of fd for listing files.

## Installation

Install with a plugin manager such as:

[packer](https://github.com/wbthomason/packer.nvim)

```
use 'natecraddock/nvim-find'
```

[vim-plug](https://github.com/junegunn/vim-plug)

```
Plug 'natecraddock/nvim-find'
```

# Configuration

Access the config table by requiring `nvim-find.config`. Edit the values of the config table
to change how nvim-find behaves. For example:

```lua
local cfg = require("nvim-find.config")

cfg.height = 14 -- set max height
```

## Configuration Options

The available options are as follows, with their default values:

```lua
local cfg = require("nvim-find.config")

-- maximum height of the finder
cfg.height = 20

-- maximum width of the finder
cgf.width = 100

-- list of ignore globs for the filename filter
-- e.g. "*.png" will ignore any file ending in .png and
-- "*node_modules*" ignores any path containing node_modules
cgf.files.ignore = {}

-- start with all result groups collapsed
cfg.search.start_closed = false
```

# Finders

Finders are not mapped by default. Each section below indicates which function to map to enable
quick access to the finder. The default command is also listed if available.

If a finder is **transient** then it can be closed immediately with <kbd>esc</kbd>. A **non-transient**
finder will return to normal mode when <kbd>esc</kbd> is pressed.

Finders open centered at the top of the terminal window. Any finder with a file preview draws centered
and is expanded to fill more of the available space.

## General

These mappings are always enabled when a finder is open

Key(s) | Mapping
-------|--------
<kbd>ctrl-j</kbd> or <kbd>ctrl-n</kbd> | select next result
<kbd>ctrl-k</kbd> or <kbd>ctrl-p</kbd> | select previous result
<kbd>ctrl-c</kbd>                      | close finder
<kbd>esc</kbd> or <kbd>ctrl-[</kbd>    | close finder if transient or enter normal mode

A **non-transient** finder has the following additional mappings in normal mode

Key(s) | Mapping
-------|--------
<kbd>j</kbd> or <kbd>n</kbd> | select next result
<kbd>k</kbd> or <kbd>p</kbd> | select previous result
<kbd>ctrl-c</kbd> or  <kbd>esc</kbd> or <kbd>ctrl-[</kbd> | close finder

## Files
**Transient**. Find files in the current working directory.

Because the [majority of file names are unique](https://nathancraddock.com/posts/in-search-of-a-better-finder/)
within a project, the file finder does not do fuzzy-matching. The query is separated into space-delimited tokens.
The first token is used to filter the file list by file name. The remaining tokens are used to further reduce the
list of results by matching against the full file paths.

Additionally, if no matches are found, then the first token will be matched against the full path rather than only
the filename.

Although this finder does not do fuzzy-matching, there is still some degree of sloppiness allowed. If the characters
`-_.` are not included in the query they will be ignored in the file paths. For example, the query
`outlinerdrawc` matches the file `outliner_draw.c`.

This algorithm is the main reason I created `nvim-find`.

Example mapping:
```
nnoremap <silent> <c-p> :lua require("nvim-find.defaults").files()<cr>
```

**Command:** `:NvimFindFiles`

Key | Mapping
----|--------
<kbd>enter</kbd>  | open selected file in last used buffer
<kbd>ctrl-v</kbd> | split vertically and open selected file
<kbd>ctrl-s</kbd> | split horizontally and open selected file
<kbd>ctrl-t</kbd> | open selected file in a new tab

## Buffers
**Transient**. List open buffers.

Lists open buffers. The alternate buffer is labeled with `(alt)`, and any buffers with unsaved changes
are prefixed with a circle icon.

Example mapping:
```
nnoremap <silent> <leader>b :lua require("nvim-find.defaults").buffers()<cr>
```

**Command:** `:NvimFindBuffers`

Key | Mapping
----|--------
<kbd>enter</kbd>  | open selected file in last used buffer
<kbd>ctrl-v</kbd> | split vertically and open selected file
<kbd>ctrl-s</kbd> | split horizontally and open selected file
<kbd>ctrl-t</kbd> | open selected file in a new tab

## Search (`ripgrep`)
**Non-transient**. Search files in the current working directory with ripgrep with a preview.

This finder shows a preview of the match in context of the file. The results are grouped by file,
and <kbd>tab</kbd> can be used to expand or collapse a file's group. After choosing a result the
lines are also sent to the quickfix list for later reference.

### Search at cursor
To search for the word under the cursor, an additional function is exposed
`require("nvim-find.defaults").search_at_cursor()`.

In cases where more than a single word should be searched for, the desired text can be selected
in visual mode. Then calling `require("nvim-find.defaults").search()` will search for the selected
text. This requires a visual mode mapping.

Example mapping:
```
nnoremap <silent> <leader>f :lua require("nvim-find.defaults").search()<cr>
```

**Command:** `:NvimFindSearch`


Key | Mapping
----|--------
<kbd>gg</kbd>     | scroll to the top of the list
<kbd>G</kbd>      | scroll to the bottom of the list
<kbd>tab</kbd>    | open or close current group fold
<kbd>o</kbd>      | open or close all group folds (toggles)
<kbd>ctrl-q</kbd> (insert) or <kbd>q</kbd> (normal) | send results to the quickfix list and close
<kbd>enter</kbd>  | insert: switch to normal mode. normal: open selected match in last used buffer
<kbd>ctrl-v</kbd> | split vertically and open selected match
<kbd>ctrl-s</kbd> | split horizontally and open selected match
<kbd>ctrl-t</kbd> | open selected match in a new tab

# Contributing
If you find a bug, have an idea for a new feature, or even write some code you want included, please
create an issue or pull request! I would appreciate contributions. Note that plan to keep nvim-find
simple, focused, and opinionated, so not all features will be accepted.

## Acknowledgements

This is my first vim/neovim plugin, and first project in Lua. I have relied on
[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim),
[plenary.nvim](https://github.com/nvim-lua/plenary.nvim),
and [Snap](https://github.com/camspiers/snap) for help on how to interact with the neovim api, and for
inspiration on various parts of this plugin. Thanks to all the developers for helping me get started!

The async design of nvim-find is most heavily inspired by Snap.
