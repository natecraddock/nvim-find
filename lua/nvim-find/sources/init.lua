-- Easier access to sources by name

local sources = {}

sources.buffers = require("nvim-find.sources.buffers").run
sources.fd = require("nvim-find.sources.fd").run
sources.rg = require("nvim-find.sources.rg").run

return sources
