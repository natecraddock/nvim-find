local config = require("nvim-find.config")
local find_file = require("nvim-find.defaults.files")
local find_search = require("nvim-find.defaults.search")
local find_buffer = require("nvim-find.defaults.buffers")

local nvim_find = {}

-- User configuration
nvim_find.setup = config.setup

-- Default file finder
nvim_find.files = find_file.open

-- Default buffer finder
nvim_find.buffers = find_buffer.open

-- Default search (ripgrep) finder
nvim_find.search = find_search.open

return nvim_find
