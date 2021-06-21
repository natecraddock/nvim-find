-- Easier access to filters by name

local cache = require("nvim-find.filters.cache")
local file = require("nvim-find.filters.file")
local simple = require("nvim-find.filters.simple")

local filters = {}

filters.cache = cache.run
filters.file = file.run
filters.join = nil
filters.simple = simple.run

return filters
