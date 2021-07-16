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

-- fd or rg file picker
function defaults.files()
  if not file_source then
    file_source = get_best_file_source()
    file_source = filters.wrap(file_source)
  end

  find.create({
    source = filters.sort(filters.filename(filters.cache(file_source))),
    transient = true,
  })
end

-- vim buffers
function defaults.buffers()
  find.create({
    source = filters.simple(sources.buffers),
    transient = true,
  })
end

-- ripgrep project search
local function vimgrep(lines)
  local ret = {}
  local dir = ""

  for _, line in ipairs(lines) do
    local filepath, row, col, match = string.match(line, "(.-):(.-):(.-):(.*)")
    if dir ~= filepath then
      table.insert(ret, { open = true, result = filepath })
      dir = filepath
    end

    table.insert(ret, {
      path = filepath,
      line = tonumber(row),
      col = tonumber(col),
      result = utils.str.trim(match),
    })
  end

  return ret
end

local function fill_quickfix(lines)
  local qfitems = {}
  for _, line in ipairs(lines) do
    table.insert(qfitems, { filename = line.path, lnum = line.line, col = line.col, text = line.result })
  end
  vim.fn.setqflist(qfitems)

  utils.notify(string.format("%s items added to quickfix list", #qfitems))
end

function defaults.search()
  find.create({
    source = filters.wrap(sources.rg_grep, vimgrep),
    events = {{ mode = "n", key = "q", close = true, fn = fill_quickfix },
              { mode = "i", key = "<c-q>", close = true, fn = fill_quickfix }},
    preview = true,
    toggles = true,
    fn = fill_quickfix,
  })
end

function defaults.test()
  find.create({
    source = filters.simple(filters.join(sources.buffers, sources.buffers)),
    events = {},
  })
end

return defaults
