-- finder.lua
-- Contains the generic code used to manage each type of finder

local state = require("nvim-find.state")
local str = require("nvim-find.string-utils")

local api = vim.api

local finder = {}

-- Default filter for finders
local function basic_filter(input, query)
  local matches = {}
  for _, entry in ipairs(input) do
    if string.find(entry, query, 1, true) then
      table.insert(matches, entry)
    end
  end
  return matches
end

local Finder = {
  source = nil,
  filter = nil,
  previewer = nil,
  events = nil,
  event_map = {},
  state = {
    closed = nil,
    previous_window = nil,
  },
  prompt = {
    buffer = nil,
    window = nil,
    query = "",
  },
  results = {
    buffer = nil,
    window = nil,
    all = nil,
    length = 0,
    filtered = {},
    selected = 0,
  },
  preview = {
    enabled = false,
    buffer = nil,
    window = nil,
  },
  callback = false,
}

-- Create a new popup given a row, column, width, and height
-- Returns the created buffer and window in a table
local function create_popup(options)
  local buffer = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buffer, "bufhidden", "wipe")
  api.nvim_buf_set_option(buffer, "buflisted", false)

  local opts = {
    style = "minimal",
    relative = "editor",
    row = options.row,
    col = options.col,
    width = options.width,
    height = options.height,
  }

  local window = api.nvim_open_win(buffer, true, opts)

  return { buffer = buffer, window = window }
end

-- Create a new finder
function Finder:new(opts)
  if not opts then
    error("opts must not be nil")
  end

  local f = {}
  self.__index = self
  setmetatable(f, self)

  if not opts.source then
    error("opts must contain a source")
  end
  f.source = opts.source

  f.filter = opts.filter or basic_filter

  if not opts.events then
    error("opts must contain events")
  end
  f.events = opts.events

  -- TODO: Only enable preview when needed
  if opts.preview then
    f.preview.enabled = true
    f.previewer = opts.preview
  else
    f.preview_enabled = false
    f.previewer = nil
  end

  f.callback = opts.callback ~= nil

  f.prompt.query = ""
  f.results.all = nil
  f.results.filtered = {}

  return f
end

local function get_finder_dimensions(preview_enabled)
  local vim_width = api.nvim_get_option("columns")
  local vim_height = api.nvim_get_option("lines")

  local finder_height = math.min(20, math.ceil(vim_height / 2))
  local finder_width = math.ceil(vim_width * 0.8)
  local column = math.ceil((vim_width - finder_width) / 2)

  local column_preview
  local width_preview
  local height_preview
  if preview_enabled then
    local w = finder_width
    finder_width = math.ceil(finder_width * 0.4)
    width_preview = w - finder_width
    column_preview = column + finder_width
    height_preview = finder_height + 1
  end

  return {
    column = column,
    width = finder_width,
    height = finder_height,
    column_preview = column_preview,
    width_preview = width_preview,
    height_preview = height_preview,
  }
end

function Finder:run_mapping(map)
  local mapping = self.event_map[map]
  if mapping.type == "select" then
    self:select(mapping.callback)
  else
    mapping.callback()
  end
end

local function set_mapping(buffer, key, event_num, options)
  local rhs = string.format("<cmd>:lua require('nvim-find.state').run_mapping(%s)<cr>", event_num)
  api.nvim_buf_set_keymap(buffer, "i", key, rhs, options)
end

local function set_autocommand(event, buffer, event_num)
  local cmd = string.format("autocmd %s <buffer=%s> :lua require('nvim-find.state').run_mapping(%s)",
                            event,
                            buffer,
                            event_num)
  api.nvim_command(cmd)
end

-- Events not triggered directly by any action
local function register_event(f, type, callback)
  if type == "move_cursor_before" then
    f.move_cursor_before = callback
  elseif type == "move_cursor_after" then
    f.move_cursor_after = callback
  end
end

-- Set the autocommands and keybindings for the finder
function Finder:set_events(buffer)
  local options = { nowait = true, silent = true, noremap = true }

  local default_events = {
    { key = "<esc>", callback = function() self:close(true) end },
    { key = "<c-c>", callback = function() self:close(true) end },
    { key = "<c-j>", callback = function() self:move_cursor('down') end },
    { key = "<c-k>", callback = function() self:move_cursor('up') end },
    { key = "<c-n>", callback = function() self:move_cursor('down') end },
    { key = "<c-p>", callback = function() self:move_cursor('up') end },
    { event = "BufLeave", callback = function() self:close(true) end },
    { event = "InsertLeave", callback = function() self:close(true) end },
    { event = "TextChangedI", callback = function() self:search() end },
  }

  local event_num = 1
  for _, event in ipairs(default_events) do
    self.event_map[event_num] = event
    if event.key then
      set_mapping(buffer, event.key, event_num, options)
    elseif event.event then
      set_autocommand(event.event, buffer, event_num)
    end
    event_num = event_num + 1
  end

  for _, event in ipairs(self.events) do
    if event.key then
      self.event_map[event_num] = event
      set_mapping(buffer, event.key, event_num, options)
      event_num = event_num + 1
    else
     -- These are probably better as just callbacks passed in?
      register_event(self, event.type, event.callback)
    end
  end
end

function Finder:_open_popups(dimensions)
  local prompt = create_popup({
    row = 0,
    col = dimensions.column,
    width = dimensions.width,
    height = 1,
  })

  self.prompt.buffer = prompt.buffer
  self.prompt.window = prompt.window

  if self.prompt.query ~= "" then
    api.nvim_buf_set_lines(self.prompt.buffer, 0, 1, false, {self.prompt.query})
  end

  local results = create_popup({
    row = 1,
    col = dimensions.column,
    width = dimensions.width,
    height = dimensions.height,
  })

  self.results.buffer = results.buffer
  self.results.window = results.window

  api.nvim_win_set_option(results.window, "cursorline", true)

  api.nvim_buf_set_lines(results.buffer, 0, 0, false, self.results.all)
  self.results.length = #self.results.all
  api.nvim_win_set_cursor(results.window, { 1, 0 })

  -- Ensure the prompt is the focused window and in insert mode
  api.nvim_set_current_win(prompt.window)

  vim.cmd [[startinsert!]]

  -- Must set keymappings and autocommands after creating all buffers
  -- otherwise the BufLeave autocommand would trigger when creating the
  -- results window, and then later attempts to modify the prompt window
  -- had a chance of failing if the prompt window had already been removed.
  self.event_map = {}
  self:set_events(prompt.buffer)

  state.finder = self
end

function Finder:open()
  self.results.all = self.source()

  local dimensions = get_finder_dimensions()

  self.state.previous_window = api.nvim_get_current_win()
  self.state.closed = false

  self.prompt.query = ""
  self:_open_popups(dimensions)
end

function Finder:_close_popup(popup)
  if self[popup].buffer or self[popup].window then
    if self[popup].window then api.nvim_win_close(self[popup].window, true) end
  end
  self[popup].buffer = nil
  self[popup].window = nil
end

function Finder:open_preview()
  if not self.preview.enabled then
    return
  end

  self.state.swapping = true

  -- Close all windows
  self:_close_popup("prompt")
  self:_close_popup("results")
  self:_close_popup("preview")

  local dimensions = get_finder_dimensions(true)

  local preview = create_popup({
    row = 0,
    col = dimensions.column_preview,
    width = dimensions.width_preview,
    height = dimensions.height_preview,
  })

  self.preview.buffer = preview.buffer
  self.preview.window = preview.window

  api.nvim_win_set_option(preview.window, "cursorline", true)

  self:_open_popups(dimensions)

  self.state.swapping = false
end

function Finder:close_preview()
  if not self.preview.enabled then
    return
  end

  self.state.swapping = true

  -- Close all windows
  self:_close_popup("prompt")
  self:_close_popup("results")
  self:_close_popup("preview")

  local dimensions = get_finder_dimensions()
  self:_open_popups(dimensions)

  self.state.swapping = false
end

-- Used to close the prompt and results windows if they are open.
--
-- If neither window is open then nothing will happen.
--
-- Will also switch to normal mode if in insert mode.
function Finder:close(cancel)
  -- Swapping to a new layout will trigger autocommands so we need to keep this
  -- from running
  if self.state.swapping then return end

  if self.state.closed then return end
  self.state.closed = true

  self:_close_popup("prompt")
  self:_close_popup("results")
  self:_close_popup("preview")

  if cancel then
    api.nvim_set_current_win(self.state.previous_window)
  end

  -- TODO: This is messy, is there a better way?
  if api.nvim_get_mode().mode ~= "n" then
    api.nvim_feedkeys(api.nvim_replace_termcodes("<esc>", true, true, true), "m", true)
  end

  state.finder = nil
end

local function get_prompt(buffer)
  local line = api.nvim_buf_get_lines(buffer, 0, 1, false)[1]
  return str.trim(line)
end

function Finder:fill_results(lines)
  api.nvim_buf_set_lines(self.results.buffer, 0, self.results.length, false, lines)
  api.nvim_win_set_cursor(self.results.window, { 1, 0 })
  self.results.length = #lines
  self.results.lines = lines
end

function Finder:search()
  local query = get_prompt(self.prompt.buffer)
  self.prompt.query = query

  if self.callback then
    self.filter(self.results.all, query, function(lines) self:fill_results(lines) end)
  else
    self.results.filtered = self.filter(self.results.all, query)
    self:fill_results(self.results.filtered)
  end
end

function Finder:move_cursor(direction)
  local cursor = api.nvim_win_get_cursor(self.results.window)
  local length = self.results.length

  if self.move_cursor_before then
    if not self.move_cursor_before(cursor, direction) then
      return
    end
  end

  if direction == "up" and cursor[1] > 1 then
    cursor[1] = cursor[1] - 1
  elseif direction == "down" and cursor[1] < length then
    cursor[1] = cursor[1] + 1
  end
  api.nvim_win_set_cursor(self.results.window, cursor)

  -- TODO: Abstract into "get_line" function
  if self.preview.window then
    local row = cursor[1]
    self.previewer(row, self.preview.window, self.preview.buffer)
  end

  -- if self.move_cursor_after then
  --   self.move_cursor_after(cursor)
  -- end

  -- TODO: Is there a better way to redraw only one window?
  vim.cmd("redraw!")
end

-- Run the event on the current row
function Finder:select(callback)
  local row = api.nvim_win_get_cursor(self.results.window)[1]
  local selected = api.nvim_buf_get_lines(self.results.buffer, row - 1, row, false)[1]

  if selected == "" then
    self:close(true)
    return
  end

  self:close()
  api.nvim_set_current_win(self.state.previous_window)

  callback(selected, row)
end

finder.Finder = Finder

return finder
