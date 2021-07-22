-- Default finders

local config = require("nvim-find.config")
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

-- sort by rank then by line length
local function ranked_sort(to_sort)
  table.sort(to_sort, function(a, b)
    if a.rank == b.rank then
      return #a.result < #b.result
    end
    return a.rank > b.rank
  end)
end

function defaults.files()
  if not file_source then
    file_source = get_best_file_source()
    file_source = filters.wrap(file_source)
  end

  find.create({
    source = filters.sort(filters.filename(filters.cache(file_source)), 100, ranked_sort),
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
      table.insert(ret, { open = not config.search.start_closed, result = filepath })
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
    if line.open == nil then
      table.insert(qfitems, { filename = line.path, lnum = line.line, col = line.col, text = line.result })
    end
  end
  vim.fn.setqflist(qfitems)

  utils.notify(string.format("%s items added to quickfix list", #qfitems))
end

function defaults.search(at_cursor)
  local query = nil

  -- Get initial query if needed
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" then
    query = utils.vim.visual_selection()
    -- HACK: is there an easier way to exit normal mode?
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "n", true)
  elseif at_cursor then
    local word_at_cursor = vim.fn.expand("<cword>")
    if word_at_cursor ~= "" then query = word_at_cursor end
  end

  find.create({
    source = filters.wrap(sources.rg_grep, vimgrep),
    events = {{ mode = "n", key = "q", close = true, fn = fill_quickfix },
              { mode = "i", key = "<c-q>", close = true, fn = fill_quickfix }},
    layout = "full",
    preview = true,
    toggles = true,
    query = query,
    fn = fill_quickfix,
  })
end

function defaults.search_at_cursor()
  defaults.search(true)
end

function defaults.test()
  find.create({
    source = filters.simple(filters.join(sources.buffers, sources.buffers)),
    events = {},
  })
end

return defaults
