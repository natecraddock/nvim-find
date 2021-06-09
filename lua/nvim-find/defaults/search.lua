local Job = require("nvim-find.job")
local fs = require("nvim-find.fs")
local finder = require("nvim-find.finder")
local str = require("nvim-find.string-utils")
local path = require("nvim-find.path")

local search = {}

local job = nil
local search_finder = nil

local api = vim.api
local function parse_vimgrep_line(grep_line)
  local filepath, row, column, match = string.match(grep_line, "(.-):(.-):(.-):(.*)")

  return {
    path = filepath,
    row = tonumber(row),
    col = tonumber(column),
    match = str.trim(match),
  }
end

local function rg(query, callback)
  if job then
    job:stop()
  end
  job = Job:new("rg", {"--vimgrep", query}, callback)
  job:start()
end

local line_index = {}
local function filter(_, query, callback)
  line_index = {}
  local index = {}
  if query == "" or #query <= 3 then
    callback({})
    return
  end
  local cb = vim.schedule_wrap(function(results)
    for _, line in ipairs(results) do
      local data = parse_vimgrep_line(line)
      if data then
        if index[data.path] == nil then
          index[data.path] = {}
        end
        table.insert(index[data.path], {match = data.match, row = data.row, col = data.col})
      end
    end

    local display = {}
    for p, l in pairs(index) do
      table.insert(line_index, {path = p, row = 1, col = 1, ignore = true})
      table.insert(display, path.basename(p) .. " (" .. p .. ")")
      for _, m in ipairs(l) do
        table.insert(line_index, {path = p, row = m.row, col = m.col, text=m.match})
        table.insert(display, " │ " .. m.match)
      end
    end

    callback(display)
  end)
  rg(query, cb)
end

local cursor_mode = false

local function move_cusor(cursor, direction)
  if not cursor_mode then
    if cursor[1] == 1 and direction == "down" then
      cursor_mode = true
      search_finder:open_preview()
      return false
    end
  else
    -- On first row
    if cursor[1] == 1 and direction == "up" then
      cursor_mode = false
      search_finder:close_preview()
      return false
    end
  end
  return true
end

local loaded_buffers = {}
local function preview(index, window, buffer)
  local line = line_index[index]

  if loaded_buffers[line.path] == nil then
    loaded_buffers[line.path] = fs.readlines(fs.read(line.path))
  end

  api.nvim_buf_call(buffer, function()
    -- TODO: Store this locally rather than calulating each time
    local length = vim.fn.line("$")
    api.nvim_buf_set_lines(buffer, 0, length, false, loaded_buffers[line.path])
    api.nvim_win_set_cursor(window, { line.row, line.col })
  end)
end

local function open_file(line, split)
  local command = "edit"
  if split then command = split end
  vim.cmd(string.format(":%s +%s %s", command, line.row, line.path))
end

local function fill_quickfix()
  local qfitems = {}
  for _, result in ipairs(line_index) do
    if not result.ignore then
      table.insert(qfitems, {filename=result.path, lnum=result.row, col=result.col, text=result.text})
    end
  end
  vim.fn.setqflist(qfitems)
end

local function select(row, split)
  local line = line_index[row]

  if cursor_mode then
    open_file(line, split)
  end

  -- Always fill the quickfix for usefulness
  fill_quickfix()
end

local events = {
  { key = "<cr>", type = "select", callback = function(_, row) select(row) end },
  { key = "<c-s>", type = "select", callback = function(_, row) select(row, "split") end },
  { key = "<c-v>", type = "select", callback = function(_, row) select(row, "vsplit") end },
  { key = "<c-t>", type = "select", callback = function(_, row) select(row, "tabedit") end },
  { type = "move_cursor_before", callback = move_cusor },
}

function search.open()
  loaded_buffers = {}
  cursor_mode = false
  line_index = {}

  search_finder = finder.Finder:new({
    source = function() return {} end,
    filter = filter,
    events = events,
    preview = preview,
    callback = true,
  })

  search_finder:open()
end

return search
