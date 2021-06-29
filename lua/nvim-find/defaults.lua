-- Default finders

local filters = require("nvim-find.filters")
local find = require("nvim-find")
local sources = require("nvim-find.sources")
local utils = require("nvim-find.utils")

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
end

local file_source = nil

function defaults.files()
  if not file_source then
    file_source = get_best_file_source()
    file_source = filters.wrap(file_source)
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

local function vimgrep(line)
  local filepath, row, col, match = string.match(line, "(.-):(.-):(.-):(.*)")
  return {
    path = filepath,
    line = tonumber(row),
    col = tonumber(col),
    result = utils.str.trim(match),
  }
end

function defaults.search()
  find.create({
    source = filters.wrap(sources.rg_grep, vimgrep),
    events = {},
    preview = true,
  })
end

function defaults.test()
  find.create({
    source = filters.simple(filters.join(sources.buffers, sources.buffers)),
    events = {},
  })
end

return defaults
