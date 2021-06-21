-- Default finders

local config = require("nvim-find.config")
local filters = require("nvim-find.filters")
local find = require("nvim-find")
local sources = require("nvim-find.sources")

local defaults = {}

-- TODO:: Move user config to a separate file
find.setup = config.setup

function defaults.files()
  find.create({
    source = filters.filename(filters.cache(sources.fd)),
    events = {},
  })
end

function defaults.buffers()
  find.create({
    source = filters.simple(sources.buffers),
    events = {},
  })
end

function defaults.search()
  find.create({
    source = sources.rg,
    events = {},
  })
end

return defaults
