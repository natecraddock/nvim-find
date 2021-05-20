# nvim-find

A simple plugin to help find files quickly and accurately

## Features

## Installation

**Requires Neovim >= v0.5.0**

Install with a package manager such as:

[vim-plug](https://github.com/junegunn/vim-plug)

```
Plug 'natecraddock/nvim-find'
```

or

[packer](https://github.com/wbthomason/packer.nvim)

```
use 'natecraddock/nvim-find'
```

If you have instructions for another not listed, please send a pull request!

## Usage

To open the finder you need to configure a mapping, here is an example to bind to <kbd>ctrl+p</kbd>
in normal mode.

```
nnoremap <silent> <c-p> :lua require("nvim-find").files()<cr>
```

Once the popup is open there are some default mappings enabled:

ctrl+j | down
ctrl+k | up
ctrl+n | down
ctrl+p | up
cr     | open file in last buffer
ctrl+v | split vertically and open
ctrl+s | split horizontally and open

Any of esc, ctrl+[ and ctrl+c will close the finder immediately.

## Roadmap

