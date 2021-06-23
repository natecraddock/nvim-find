-- Easier access to sources by name

local sources = {}

sources.buffers = require("nvim-find.sources.buffers").run
sources.fd = require("nvim-find.sources.fd").run
sources.rg_grep = require("nvim-find.sources.rg").grep
sources.rg_files = require("nvim-find.sources.rg").files

return sources
