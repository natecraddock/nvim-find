-- Easier access to filters by name

local filters = {}

filters.cache = require("nvim-find.filters.cache").run
filters.filename = require("nvim-find.filters.filename").run
filters.join = require("nvim-find.filters.join").run
filters.simple = require("nvim-find.filters.simple").run
filters.sort = require("nvim-find.filters.sort").run

return filters
