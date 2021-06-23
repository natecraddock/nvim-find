-- nvim-find: A fast, simple, async finder plugin

local async = require("nvim-find.async")
local mappings = require("nvim-find.mappings")
local str = require("nvim-find.string-utils")

local find = {}

local api = vim.api

-- TODO: Tidy up the preview window stuff
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
function find.create(opts)
  if not opts then
    error("opts must not be nil")
  end

  if not opts.source then
    error("opts must contain a source")
  end

  -- Tracks if the finder is running
  local open = true

  local last_query = ""

  -- A source wrapped by zero or more filters
  local source = opts.source

  -- TODO: Only enable preview when needed
  -- if opts.preview then
  --   f.preview.enabled = true
  --   f.previewer = opts.preview
  -- else
  --   f.preview_enabled = false
  --   f.previewer = nil
  -- end

  local last_window = api.nvim_get_current_win()

  -- Create all popups needed for this finder
  local dimensions = get_finder_dimensions()

  local prompt = create_popup(0, dimensions.column, dimensions.width, 1)
  -- Strangely making the buffer a prompt type will trigger the event loop
  -- but a normal buffer won't be triggered until a character is typed
  api.nvim_buf_set_option(prompt.buffer, "buftype", "prompt")
  vim.fn.prompt_setprompt(prompt.buffer, "> ")
  api.nvim_command("startinsert")

  local results = create_popup(1, dimensions.column, dimensions.width, dimensions.height)
  api.nvim_win_set_option(results.window, "cursorline", true)

  results.scroll = 1
  results.lines = {}

  local function close()
    open = false

    -- Close all open popups
    prompt.close()
    results.close()

    api.nvim_set_current_win(last_window)

    api.nvim_command("stopinsert")
  end

  local function map(l, fn)
    local r = {}
    for _, line in ipairs(l) do
      table.insert(r, fn(line))
    end
    return r
  end

  -- Fill the results buffer with the lines visible at the current cursor and scroll offsets
  local function fill_results(lines)
    if not open then return end

    local partial_lines = { unpack(lines, results.scroll, results.scroll + dimensions.height) }
    api.nvim_buf_set_lines(results.buffer, 0, -1, false, map(partial_lines, function(v) return v.result end))
  end

  local function choose(command)
    command = command or "edit"

    local row = api.nvim_win_get_cursor(results.window)[1]
    local selected = api.nvim_buf_get_lines(results.buffer, row - 1, row, false)[1]

    close()

    -- Nothing was selected so just close
    if selected == "" then
      return
    end

    -- TODO: Allow custom callback based on the selected data
    -- callback(selected, row)
    api.nvim_command(string.format("%s %s", command, selected))
  end

  local function move_cursor(direction)
    local cursor = api.nvim_win_get_cursor(results.window)
    local length = #results.lines

    if direction == "up" then
      if cursor[1] > 1 then
        cursor[1] = cursor[1] - 1
      elseif results.scroll > 1 then
        results.scroll = results.scroll - 1
      end
    elseif direction == "down" then
      if cursor[1] < dimensions.height then
        cursor[1] = cursor[1] + 1
      elseif results.scroll <= length - dimensions.height then
        results.scroll = results.scroll + 1
      end
    end

    api.nvim_win_set_cursor(results.window, cursor)

    -- Always redraw the lines to force a window redraw
    fill_results(results.lines)
  end

  -- TODO: These default events are hard coded for file opening
  local default_events = {
    { type = "keymap", key = "<esc>", fn = close },
    { type = "keymap", key = "<c-c>", fn = close },
    { type = "autocmd", event = "InsertLeave", fn = close },

    { type = "keymap", key = "<cr>", fn = choose },
    { type = "keymap", key = "<c-s>", fn = function() choose("split") end },
    { type = "keymap", key = "<c-v>", fn = function() choose("vsplit") end },
    { type = "keymap", key = "<c-t>", fn = function() choose("tabedit") end },

    { type = "keymap", key = "<c-j>", fn = function() move_cursor("down") end },
    { type = "keymap", key = "<c-k>", fn = function() move_cursor("up") end },
    { type = "keymap", key = "<c-n>", fn = function() move_cursor("down") end },
    { type = "keymap", key = "<c-p>", fn = function() move_cursor("up") end },
  }

  -- BUG: fails if opts.events doesn't exist
  local events = vim.tbl_extend("keep", default_events, opts.events)
  for _, event in ipairs(events) do
    mappings.add(prompt.buffer, event)
  end

  local function get_prompt(buffer)
    local line = api.nvim_buf_get_lines(buffer, 0, 1, false)[1]
    return str.trim(line:sub(3))
  end

  local function prompt_changed()
    -- Reset the cursor and scroll offset
    api.nvim_win_set_cursor(results.window, { 1, 0 })
    results.scroll = 1
    results.lines = {}

    last_query = get_prompt(prompt.buffer)

    -- Stores info on the current finder
    local finder = {
      query = last_query,
    }

    function finder.is_closed()
      return not open or (finder.query ~= last_query)
    end

    local function on_value(value)
      for _, val in ipairs(value) do
        if val and val ~= "" then
          table.insert(results.lines, val)
        end
      end
      vim.schedule(function()
        fill_results(results.lines)
      end)
    end

    -- Run the event loop
    async.loop({
      finder = finder,
      source = source,
      on_value = on_value,
    })
  end

  api.nvim_buf_attach(prompt.buffer, false, { on_lines = prompt_changed, on_detach = function() end })

  -- Ensure the prompt is the focused window
  api.nvim_set_current_win(prompt.window)
end

return find
