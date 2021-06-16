-- finder.lua
-- Contains the generic code used to manage each type of finder

local mappings = require("nvim-find.mappings")
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

-- Create a new popup given a row, column, width, and height
-- Returns the created buffer and window in a table
local function create_popup(row, col, width, height)
  local buffer = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buffer, "bufhidden", "wipe")
  api.nvim_buf_set_option(buffer, "buflisted", false)

  local opts = {
    style = "minimal",
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
  }

  local window = api.nvim_open_win(buffer, true, opts)

  -- Used to close the window when finished or canceled
  local close = function()
    if buffer or window then
      if window then api.nvim_win_close(window, true) end
    end
  end

  return { buffer = buffer, window = window, close = close }
end

-- Create and open a new finder
function finder.create(opts)
  local config = {}

  if not opts then
    error("opts must not be nil")
  end

  if not opts.source then
    error("opts must contain a source")
  end
  local source = opts.source

  local filter = opts.filter or basic_filter

  if not opts.events then
    error("opts must contain events")
  end

  -- TODO: Only enable preview when needed
  -- if opts.preview then
  --   f.preview.enabled = true
  --   f.previewer = opts.preview
  -- else
  --   f.preview_enabled = false
  --   f.previewer = nil
  -- end

  local callback = opts.callback ~= nil

  local label_str = opts.label or "> "

  local last_window = api.nvim_get_current_win()

  -- Create all popups needed for this finder
  local dimensions = get_finder_dimensions()
  local label_len = #label_str
  local label = create_popup(0, dimensions.column, label_len, 1)
  api.nvim_buf_set_lines(label.buffer, 0, 1, false, { label_str })

  local prompt = create_popup(0, dimensions.column + label_len, dimensions.width - label_len, 1)
  vim.cmd [[startinsert!]]

  local results = create_popup(1, dimensions.column, dimensions.width, dimensions.height)
  api.nvim_win_set_option(results.window, "cursorline", true)

  local function close(cancel)
    label.close()
    prompt.close()
    results.close()

    if cancel then
      api.nvim_set_current_win(last_window)
    end

    -- TODO: This is messy, is there a better way? Is it even needed
    if api.nvim_get_mode().mode ~= "n" then
      api.nvim_feedkeys(api.nvim_replace_termcodes("<esc>", true, true, true), "m", true)
    end
  end

  -- Ensure the prompt is the focused window and in insert mode
  api.nvim_set_current_win(prompt.window)

  local function fill_results(lines)
    vim.schedule_wrap(function()
      api.nvim_buf_set_lines(self.results.buffer, 0, -1, false, lines)
      api.nvim_win_set_cursor(self.results.window, { 1, 0 })
      self.results.length = #lines
      self.results.lines = lines
    end)()
  end

  local function get_prompt(buffer)
    local line = api.nvim_buf_get_lines(buffer, 0, 1, false)[1]
    return str.trim(line)
  end

  local function search()
    local query = get_prompt(prompt.buffer)
    print(query)
    -- fill_results(filter(f.results.all, query))
  end

  local default_events = {
    { type = "keymap", key = "<esc>", fn = close},
    { type = "keymap", key = "<c-c>", fn = close },
    -- { type = "keymap", key = "<c-j>", fn = function() self:move_cursor('down') end },
    -- { type = "keymap", key = "<c-k>", fn = function() self:move_cursor('up') end },
    -- { type = "keymap", key = "<c-n>", fn = function() self:move_cursor('down') end },
    -- { type = "keymap", key = "<c-p>", fn = function() self:move_cursor('up') end },
    { type = "autocmd", event = "InsertLeave", fn = close },
  }

  local events = vim.tbl_extend("keep", default_events, opts.events)
  for _, event in ipairs(events) do
    mappings.add(prompt.buffer, event)
  end

  api.nvim_buf_attach(prompt.buffer, false, { on_lines = search })
end

local function move_cursor(direction)
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
local function select(callback)
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

return finder
