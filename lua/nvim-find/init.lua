-- nvim-find: A fast, simple, async finder plugin

local async = require("nvim-find.async")
local config = require("nvim-find.config")
local mappings = require("nvim-find.mappings")
local utils = require("nvim-find.utils")

local find = {}

local api = vim.api

-- The finder should be kept small and unintrusive unless a preview is shown.
-- In that case it makes sense to take more of the available space.
local function get_finder_dimensions(layout, use_preview)
  local vim_width = api.nvim_get_option("columns")
  local vim_height = api.nvim_get_option("lines")

  local row, finder_width, finder_height = (function()
    if layout == "full" then
      local pad = 8
      local width = vim_width - (pad * 2)
      local height = vim_height - pad
      return 1, width, height
    elseif layout == "top" then
      local width = math.min(config.width, math.ceil(vim_width * 0.8))
      local height = math.min(config.height, math.ceil(vim_height / 2))
      return 0, width, height
    end

    error("Unsupported layout: " .. layout)
  end)()

  local width_prompt = finder_width
  if use_preview then
    width_prompt = math.ceil(finder_width * 0.4)
  end
  local width_preview = finder_width - width_prompt
  local height_preview = finder_height + 1

  local column = math.ceil((vim_width - finder_width) / 2)
  local column_preview = column + width_prompt

  return {
    row = row,
    column = column,
    width = width_prompt,
    height = finder_height,
    column_preview = column_preview,
    width_preview = width_preview,
    height_preview = height_preview,
  }
end

-- Create a new popup given a row, column, width, and height
-- Returns the created buffer and window in a table
local function create_popup(row, col, width, height, border, z)
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
    border = border,
    zindex = z,
  }

  local window = api.nvim_open_win(buffer, true, opts)
  api.nvim_win_set_option(window, "winhl", "Normal:Normal")

  -- Used to close the window when finished or canceled
  local close = function()
    if buffer or window then
      if window then api.nvim_win_close(window, true) end
    end
  end

  return { buffer = buffer, window = window, close = close }
end

local function centered_slice(data, n, w)
  -- Line that is centered
  local centered = math.ceil(w / 2)
  local before = centered - 1
  local after = centered

  if n - before < 1 then
    local diff = 1 - (n - before)
    before = before - diff
    after = after + diff
  elseif n + after > #data then
    local diff = (n + after) - #data
    before = before + diff
    after = after - diff
  end

  return utils.fn.slice(data, n - before, n + after + 1), before + 1
end

local is_finder_open = false

-- Create and open a new finder
-- TODO: Cleanup this function
function find.create(opts)
  -- Prevent opening more than one finder at a time
  if is_finder_open then return end

  if not opts then
    error("opts must not be nil")
  end

  if not opts.source then
    error("opts must contain a source")
  end

  -- the layout of the finder
  local layout = opts.layout or "top"

  -- Transient finders close on escape and are meant to be used for quick
  -- searches that narrow down quickly.
  local transient = opts.transient or false

  -- Tracks if the finder is running
  local open = true

  local last_query = ""

  -- A source wrapped by zero or more filters
  local source = opts.source

  -- Show a preview window
  local use_preview = opts.preview or false

  local last_window = api.nvim_get_current_win()

  -- Create all popups needed for this finder
  local dimensions = get_finder_dimensions(layout, use_preview)

  local borders_prompt = {"┌", "─", "┐", "│", "┘", "─", "└", "│"}
  local borders_results = {"├", "─", "┤", "│", "┘", "─", "└", "│"}
  local borders_preview = {"┬", "─", "┐", "│", "┘", "─", "┴", "│"}


  local prompt = create_popup(dimensions.row, dimensions.column, dimensions.width, 1, borders_prompt, 1)
  -- Strangely making the buffer a prompt type will trigger the event loop
  -- but a normal buffer won't be triggered until a character is typed
  api.nvim_buf_set_option(prompt.buffer, "buftype", "prompt")
  vim.fn.prompt_setprompt(prompt.buffer, "> ")
  api.nvim_command("startinsert")

  local results = create_popup(dimensions.row + 2, dimensions.column, dimensions.width, dimensions.height, borders_results, 10)
  api.nvim_win_set_option(results.window, "cursorline", true)
  api.nvim_win_set_option(results.window, "scrolloff", 0)

  local preview
  if use_preview then
    preview = create_popup(dimensions.row, dimensions.column_preview, dimensions.width_preview, dimensions.height_preview + 1, borders_preview, config.height)
  end

  results.scroll = 1
  results.all_lines = {}
  results.display_lines = {}
  results.open_count = 0

  local function close()
    if not open then return end
    open = false

    -- Close all open popups
    prompt.close()
    results.close()
    if preview then
      preview.close()
    end

    api.nvim_set_current_win(last_window)
    api.nvim_command("stopinsert")

    is_finder_open = false
  end

  local fill_preview = utils.scheduled(function(data, line, col, path)
    local lines = vim.split(data:sub(1, -2), "\n", true)

    local highlight_line = nil

    if not open then return end
    if #lines > dimensions.height then
      lines, highlight_line = centered_slice(lines, line, dimensions.height)
    else
      highlight_line = line
    end

    highlight_line = math.max(highlight_line, 1)

    api.nvim_buf_set_lines(preview.buffer, 0, -1, false, lines)

    api.nvim_buf_add_highlight(preview.buffer, -1, "Search", highlight_line - 1, col - 1, -1)

    local has_treesitter = utils.try_require("nvim-treesitter")
    local _, highlight = utils.try_require("nvim-treesitter.highlight")
    local _, parsers = utils.try_require("nvim-treesitter.parsers")

    -- Syntax highlight!
    local name = vim.fn.tempname() .. utils.path.sep .. path

    -- Prevent changing the window title when "saving" the buffer
    local title = api.nvim_get_option("title")
    api.nvim_set_option("title", false)
    api.nvim_buf_set_name(preview.buffer, name)
    api.nvim_set_option("title", title)

    api.nvim_buf_call(preview.buffer, function()
      local ignore = api.nvim_get_option("eventignore")
      api.nvim_set_option("eventignore", "FileType")
      api.nvim_command("filetype detect")
      api.nvim_set_option("eventignore", ignore)
    end)
    local filetype = api.nvim_buf_get_option(preview.buffer, "filetype")
    if filetype ~= "" then
      if has_treesitter then
        local language = parsers.ft_to_lang(filetype)
        if parsers.has_parser(language) then
          highlight.attach(preview.buffer, language)
        else
          api.nvim_buf_set_option(preview.buffer, "syntax", filetype)
        end
      else
        api.nvim_buf_set_option(preview.buffer, "syntax", filetype)
      end
    end
  end)

  local buffer_cache = {}

  local function strip_closed()
    local is_open = false
    return function(line)
      if line.open ~= nil then
        is_open = line.open
        return true
      end
      return is_open
    end
  end

  local function format_line(line)
    if opts.toggles then
      -- parent row
      if line.open ~= nil then
        if line.open then
          return " " .. line.result
        else
          return " " .. line.result
        end
      end
      -- child row
      return "│ " .. line.result
    end
    -- normal rows
    return line.result
  end

  -- Fill the results buffer with the lines visible at the current cursor and scroll offsets
  local fill_results = utils.scheduled(function(lines)
    if not open then return end

    -- Start from all the lines
    lines = lines or results.all_lines
    if opts.toggles then
      lines = vim.tbl_filter(strip_closed(), lines)
    end
    results.open_count = #lines

    results.display_lines = { unpack(lines, results.scroll, results.scroll + dimensions.height) }
    api.nvim_buf_set_lines(results.buffer, 0, -1, false, utils.fn.map(results.display_lines, format_line))

    if use_preview and #results.display_lines > 0 then
      local row = api.nvim_win_get_cursor(results.window)[1]
      local selected = results.display_lines[row]
      if selected.open ~= nil then return end

      if buffer_cache[selected.path] then
        fill_preview(buffer_cache[selected.path], selected.line or 1, selected.col or 1, selected.path)
      else
        utils.fs.read(selected.path, function(d)
          buffer_cache[selected.path] = d
          fill_preview(d, selected.line or 1, selected.col or 1, selected.path)
        end)
      end
    elseif use_preview then
      api.nvim_buf_set_lines(preview.buffer, 0, -1, false, {})
    end
  end)

  -- Expand/contract the current list item and redraw
  local function toggle()
    if not opts.toggles then return end

    local row = api.nvim_win_get_cursor(results.window)[1]
    local selected = results.display_lines[row]

    -- Find selected in all lines
    local selected_index = 0
    for i, line in ipairs(results.all_lines) do
      if selected.id == line.id then
        selected = line
        selected_index = i
        break
      end
    end

    if selected then
      while selected_index > 0 and selected.open == nil do
        selected_index = selected_index - 1
        row = row - 1
        selected = results.all_lines[selected_index]
      end
      selected.open = not selected.open
      -- Move cursor to parent
      if row < 1 then
        results.scroll = results.scroll + row - 1
        row = 1
      end
      api.nvim_win_set_cursor(results.window, { row, 0 })
      fill_results()
    end
  end

  local function choose(command)
    command = command or "edit"

    local row = api.nvim_win_get_cursor(results.window)[1]
    local selected = results.display_lines[row]

    close()

    -- Nothing was selected so just close
    if #results.display_lines == 0 then
      return
    end

    api.nvim_command(string.format("%s %s", command, selected.path))
    if selected.line then
      local win = api.nvim_get_current_win()
      api.nvim_win_set_cursor(win, { selected.line, selected.col })
    end

    -- Custom callback
    if opts.fn then
      opts.fn(results.all_lines)
    end
  end

  local function move_cursor(direction)
    local cursor = api.nvim_win_get_cursor(results.window)
    local length = results.open_count

    if direction == "up" then
      if cursor[1] > 1 then
        cursor[1] = cursor[1] - 1
      elseif results.scroll > 1 then
        results.scroll = results.scroll - 1
      end
    elseif direction == "down" then
      if cursor[1] < math.min(length, dimensions.height) then
        cursor[1] = cursor[1] + 1
      elseif results.scroll <= length - dimensions.height then
        results.scroll = results.scroll + 1
      end
    elseif direction == "top" then
      cursor[1] = 1
      results.scroll = 1
    elseif direction == "bottom" then
      cursor[1] = dimensions.height
      if length > dimensions.height then
        results.scroll = length - dimensions.height + 1
      end
    end

    -- Clamp to display lines for safety
    cursor[1] = utils.fn.clamp(cursor[1], 1, #results.display_lines)

    api.nvim_win_set_cursor(results.window, cursor)

    -- Always redraw the lines to force a window redraw
    fill_results()
  end

  -- TODO: These default events are hard coded for file opening
  local events = {
    -- Always allow closing in normal mode and with ctrl-c
    { type = "keymap", key = "<esc>", fn = close },
    { type = "keymap", key = "<c-c>", fn = close },
    { type = "keymap", mode = "i", key = "<c-c>", fn = close },

    -- Never allow leaving the prompt buffer
    { type = "autocmd", event = "BufLeave", fn = close },

    -- For toggling nested lists
    { type = "keymap", key = "<tab>", fn = toggle },
    { type = "keymap", mode = "i", key = "<tab>", fn = toggle },

    -- Convenience
    { type = "keymap", key = "gg", fn = function() move_cursor("top") end },
    { type = "keymap", key = "G", fn = function() move_cursor("bottom") end },

    { type = "keymap", key = "<cr>", fn = choose },
    { type = "keymap", key = "<c-s>", fn = function() choose("split") end },
    { type = "keymap", key = "<c-v>", fn = function() choose("vsplit") end },
    { type = "keymap", key = "<c-t>", fn = function() choose("tabedit") end },
    { type = "keymap", mode = "i", key = "<cr>", str = "<esc>" },
    { type = "keymap", mode = "i", key = "<c-s>", fn = function() choose("split") end },
    { type = "keymap", mode = "i", key = "<c-v>", fn = function() choose("vsplit") end },
    { type = "keymap", mode = "i", key = "<c-t>", fn = function() choose("tabedit") end },

    { type = "keymap", key = "j", fn = function() move_cursor("down") end },
    { type = "keymap", key = "k", fn = function() move_cursor("up") end },
    { type = "keymap", key = "n", fn = function() move_cursor("down") end },
    { type = "keymap", key = "p", fn = function() move_cursor("up") end },
    { type = "keymap", mode = "i", key = "<c-j>", fn = function() move_cursor("down") end },
    { type = "keymap", mode = "i", key = "<c-k>", fn = function() move_cursor("up") end },
    { type = "keymap", mode = "i", key = "<c-n>", fn = function() move_cursor("down") end },
    { type = "keymap", mode = "i", key = "<c-p>", fn = function() move_cursor("up") end },
  }

  local transient_events = {
    { type = "keymap", mode = "i", key = "<cr>", fn = choose },
    { type = "keymap", mode = "i", key = "<esc>", fn = close },
    { type = "autocmd", event = "InsertLeave", fn = close },
  }

  if transient then
    utils.fn.mutextend(events, transient_events)
  end

  -- User events are handled specially, and only keymaps are supported
  if opts.events then
    for _, event in ipairs(opts.events) do
      -- to inform the type checker that nothing bad is happening here
      local fn = vim.deepcopy(event.fn)

      local handler = function()
        -- close the finder if needed
        if event.close then
          close()
        end

        -- run the callback
        fn(results.all_lines)
      end

      event.fn = handler
      event.type = "keymap"
    end

    utils.fn.mutextend(events, opts.events)
  end

  for _, event in ipairs(events) do
    mappings.add(prompt.buffer, event)
  end

  local function get_prompt(buffer)
    local line = api.nvim_buf_get_lines(buffer, 0, 1, false)[1]
    return utils.str.trim(line:sub(3))
  end

  local function prompt_changed()
    -- Reset the cursor and scroll offset
    api.nvim_win_set_cursor(results.window, { 1, 0 })
    results.scroll = 1
    results.all_lines = {}
    results.display_lines = {}
    results.open_count = 0

    -- clear the lines
    fill_results({})

    last_query = get_prompt(prompt.buffer)

    -- Stores the state of the current finder
    local state = {
      query = last_query,
      last_window = last_window,
    }

    function state.closed()
      return not open
    end

    function state.changed()
      return state.query ~= last_query
    end

    local id = 1
    local function on_value(value)
      for _, val in ipairs(value) do
        if val and val ~= "" then
          -- store a unique id for each line for lookup between tables
          val.id = id
          id = id + 1
          table.insert(results.all_lines, val)
        end
      end
      results.display_lines = utils.fn.copy(results.all_lines)
      fill_results()
    end

    -- Run the event loop
    async.loop({
      state = state,
      source = source,
      on_value = on_value,
    })
  end

  api.nvim_buf_attach(prompt.buffer, false, { on_lines = prompt_changed, on_detach = function() end })

  -- Ensure the prompt is the focused window
  api.nvim_set_current_win(prompt.window)

  is_finder_open = true

end

return find
