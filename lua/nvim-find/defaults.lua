-- Default finders

local filters = require("nvim-find.filters")
local find = require("nvim-find")
local sources = require("nvim-find.sources")

local defaults = {}

local function executable(exec)
  return vim.fn.executable(exec) ~= 0
end

local function get_source(name)
  if sources[name] ~= nil then return sources[name] end
  error(string.format("The executable \"%s\" is not found", name))
end

local function get_best_file_source()
  if executable("fd") then return get_source("fd") end
  if executable("rg") then return get_source("rg_files") end
  -- TODO: implement a lua source as fallback
end

local file_source = nil

function defaults.files()
  if not file_source then
    file_source = get_best_file_source()
  end

  find.create({
    source = filters.sort(filters.filename(filters.cache(file_source))),
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
    source = sources.rg_grep,
    events = {},
  })
end

return defaults
