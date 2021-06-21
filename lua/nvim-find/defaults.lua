-- Default finders

local buffers = require("nvim-find.sources.buffers")
local cache = require("nvim-find.filters.cache")
local config = require("nvim-find.config")
local fd = require("nvim-find.sources.fd")
local file = require("nvim-find.filters.file")
local find = require("nvim-find")
local rg = require("nvim-find.sources.rg")
local simple = require("nvim-find.filters.simple")

local defaults = {}

-- User configuration
-- TODO:: Move user config to a separate file
find.setup = config.setup

function defaults.files()
  find.create({
    source = file.run(cache.run(fd.run)),
    events = {},
  })
end

function defaults.buffers()
  find.create({
    source = simple.run(buffers.run),
    events = {},
  })
end

function defaults.search()
  find.create({
    source = rg.run,
    events = {},
  })
end

return defaults
