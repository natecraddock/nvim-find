-- finder.lua
-- Contains the generic code used to manage each type of finder

local state = require("nvim-find.state")
require("nvim-find.string-utils")

local Finder = {
  source = nil,
  filter = nil,
  actions = nil,
  action_map = {},
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
}

local api = vim.api

-- Create a new popup given a row, column, width, and height
-- Returns the created buffer and window in a table
local function create_popup(options)
  local buffer = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buffer, "bufhidden", "wipe")

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

  local finder = {}
  self.__index = self
  setmetatable(finder, self)

  if not opts.source then
    error("opts must contain a source")
  end
  finder.source = opts.source

  if not opts.filter then
    error("opts must contain a filter")
  end
  finder.filter = opts.filter

  if not opts.actions then
    error("opts must contain actions")
  end
  finder.actions = opts.actions

  return finder
end

local function get_finder_dimensions()
  local vim_width = api.nvim_get_option("columns")
  local vim_height = api.nvim_get_option("lines")

  local finder_height = math.min(20, math.ceil(vim_height / 2))
  local finder_width = math.ceil(vim_width * 0.8)

  local column = math.ceil((vim_width - finder_width) / 2)

  return {
    column = column,
    height = finder_height,
    width = finder_width,
  }
end

function Finder:run_mapping(map)
  local mapping = self.action_map[map]
  if mapping.type == "accept" then
    self:accept(mapping.callback)
  elseif mapping.type == "" then
    mapping.callback()
  end
end

local function set_mapping(buffer, key, action_num, options)
  local rhs = string.format("<cmd>:lua require('nvim-find.state').run_mapping(%s)<cr>", action_num)
  api.nvim_buf_set_keymap(buffer, "i", key, rhs, options)
end

-- Set the autocommands and keybindings for the finder
function Finder:set_actions(buffer)
  local options = { nowait = true, silent = true, noremap = true }

  local default_actions = {
    { key = "<esc>", type = "", callback = function() self:close(true) end },
    { key = "<c-c>", type = "", callback = function() self:close(true) end },
    { key = "<c-j>", type = "", callback = function() self:move_cursor('down') end },
    { key = "<c-k>", type = "", callback = function() self:move_cursor('up') end },
    { key = "<c-n>", type = "", callback = function() self:move_cursor('down') end },
    { key = "<c-p>", type = "", callback = function() self:move_cursor('up') end },
  }

  local action_num = 1
  for _, action in ipairs(default_actions) do
    self.action_map[action_num] = { type = action.type, callback = action.callback }
    set_mapping(buffer, action.key, action_num, options)
    action_num = action_num + 1
  end

  for _, action in ipairs(self.actions) do
    self.action_map[action_num] = { type = action.type, callback = action.callback }
    set_mapping(buffer, action.key, action_num, options)
    action_num = action_num + 1
  end

  -- TODO: use .run_mapping() so fewer functions are exposed to global api
  api.nvim_command('autocmd BufLeave <buffer> :lua require("nvim-find.state").close(true)')
  api.nvim_command('autocmd InsertLeave <buffer> :lua require("nvim-find.state").close(true)')
  api.nvim_command("autocmd TextChangedI <buffer> :lua require('nvim-find.state').search()")
end

function Finder:open()
  self.results.all = self.source:get()

  local dimensions = get_finder_dimensions()
  state.finder = self

  self.state.previous_window = api.nvim_get_current_win()
  self.state.closed = false

  local prompt = create_popup({
    row = 0,
    col = dimensions.column,
    width = dimensions.width,
    height = 1,
  })

  api.nvim_buf_set_option(prompt.buffer, "buftype", "prompt")
  vim.fn.prompt_setprompt(prompt.buffer, "> ")

  self.action_map = {}
  self:set_actions(prompt.buffer)

  -- TODO: Encapsulate this better
  self.prompt.buffer = prompt.buffer
  self.prompt.window = prompt.window

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
  -- TODO: This triggers search
  vim.cmd [[startinsert!]]
end

-- Used to close the prompt and results windows if they are open.
--
-- If neither window is open then nothing will happen.
--
-- Will also switch to normal mode if in insert mode.
function Finder:close(cancel)
  if self.state.closed then return end

  self.state.closed = true
  if self.prompt.buffer or self.prompt.window then
    if self.prompt.window then api.nvim_win_close(self.prompt.window, true) end
  end
  self.prompt.buffer = nil
  self.prompt.window = nil

  if self.results.buffer or self.results.window then
    if self.results.window then api.nvim_win_close(self.results.window, true) end
  end
  self.results.buffer = nil
  self.results.window = nil

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
  -- Trim off the prompt char and remove leading and trailing whitespace
  line = line:sub(3):trim()
  return line
end

function Finder:search()
  local query = get_prompt(self.prompt.buffer)
  self.results.filtered = self.filter:run(self.results.all, query)
  api.nvim_buf_set_lines(self.results.buffer, 0, self.results.length, false, self.results.filtered)
  api.nvim_win_set_cursor(self.results.window, { 1, 0 })
  self.results.length = #self.results.filtered
end

function Finder:move_cursor(direction)
  local cursor = api.nvim_win_get_cursor(self.results.window)
  local length = self.results.length

  if direction == "up" and cursor[1] > 1 then
    cursor[1] = cursor[1] - 1
  elseif direction == "down" and cursor[1] < length then
    cursor[1] = cursor[1] + 1
  end

  api.nvim_win_set_cursor(self.results.window, cursor)

  -- TODO: Is there a better way to redraw only one window?
  vim.cmd("redraw!")
end

-- Run the action on the current row
function Finder:accept(callback)
  local row = api.nvim_win_get_cursor(self.results.window)[1]
  local selected = api.nvim_buf_get_lines(self.results.buffer, row - 1, row, false)[1]

  if selected == "" then
    self:close(true)
    return
  end

  self:close()
  api.nvim_set_current_win(self.state.previous_window)

  callback(selected)
end

return Finder
