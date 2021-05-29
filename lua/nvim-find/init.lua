local find_file = require("nvim-find.defaults.files")
local config = require("nvim-find.config")

local nvim_find = {}

-- User configuration
nvim_find.setup = config.setup

-- Default file finder
nvim_find.files = find_file.open

return nvim_find
