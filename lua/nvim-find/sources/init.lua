-- Easier access to sources by name

local buffers = require("nvim-find.sources.buffers")
local fd = require("nvim-find.sources.fd")
local rg = require("nvim-find.sources.rg")

local sources = {}

sources.buffers = buffers.run
sources.fd = fd.run
sources.rg = rg.run

return sources
