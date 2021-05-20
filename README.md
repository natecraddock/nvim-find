# nvim-find

A simple plugin to help find files quickly and accurately

## Features

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

Once the popup is open there are some default mappings enabled:

Key(s) | Mapping
-------|--------
<kbd>ctrl j</kbd> or <kbd>ctrl n</kbd> | down
<kbd>ctrl k</kbd> or <kbd>ctrl p</kbd> | up
<kbd>cr</kbd>     | open file in last buffer
<kbd>ctrl v</kbd> | split vertically and open
<kbd>ctrl s</kbd> | split horizontally and open

Any of <kbd>esc</kbd>, <kbd>ctrl [</kbd> and <kbd>ctrl c</kbd> will close the finder immediately.

## Roadmap

