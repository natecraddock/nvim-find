-- nvim-find: A fast, simple, async finder plugin

local async = require("nvim-find.async")
local mappings = require("nvim-find.mappings")
local utils = require("nvim-find.utils")

local find = {}

local api = vim.api

-- TODO: Tidy up the preview window stuff
local function get_finder_dimensions(use_preview)
  local vim_width = api.nvim_get_option("columns")
  local vim_height = api.nvim_get_option("lines")

  local finder_height = math.min(20, math.ceil(vim_height / 2))
  local finder_width = math.ceil(vim_width * 0.8)
  local column = math.ceil((vim_width - finder_width) / 2)

  local column_preview
  local width_preview
  local height_preview
  if use_preview then
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

  -- Show a preview window
  local use_preview = opts.preview or false

  local last_window = api.nvim_get_current_win()

  -- Create all popups needed for this finder
  local dimensions = get_finder_dimensions(use_preview)

  local borders_prompt = {"┌", "─", "┐", "│", "┘", "─", "└", "│"}
  local borders_results = {"├", "─", "┤", "│", "┘", "─", "└", "│"}
  local borders_preview = {"┬", "─", "┐", "│", "┘", "─", "┴", "│"}

  local prompt = create_popup(0, dimensions.column, dimensions.width, 1, borders_prompt, 1)
  -- Strangely making the buffer a prompt type will trigger the event loop
  -- but a normal buffer won't be triggered until a character is typed
  api.nvim_buf_set_option(prompt.buffer, "buftype", "prompt")
  vim.fn.prompt_setprompt(prompt.buffer, "> ")
  api.nvim_command("startinsert")

  local results = create_popup(2, dimensions.column, dimensions.width, dimensions.height, borders_results, 10)
  api.nvim_win_set_option(results.window, "cursorline", true)
  api.nvim_win_set_option(results.window, "scrolloff", 0)

  local preview
  if use_preview then
    preview = create_popup(0, dimensions.column_preview, dimensions.width_preview, dimensions.height_preview + 1, borders_preview, 20)
  end

  results.scroll = 1
  results.lines = {}

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

    return utils.fn.slice(data, n - before, n + after), before + 1
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
  local partial_lines = {}

  -- Fill the results buffer with the lines visible at the current cursor and scroll offsets
  local fill_results = utils.scheduled(function(lines)
    if not open then return end

    partial_lines = { unpack(lines, results.scroll, results.scroll + dimensions.height) }
    api.nvim_buf_set_lines(results.buffer, 0, -1, false, utils.fn.map(partial_lines, function(v) return v.result end))

    if use_preview and #partial_lines > 0 then
      local row = api.nvim_win_get_cursor(results.window)[1]
      local selected = partial_lines[row]
      if buffer_cache[selected.path] then
        fill_preview(buffer_cache[selected.path], selected.line, selected.col, selected.path)
      else
        utils.fs.read(selected.path, function(d)
          buffer_cache[selected.path] = d
          fill_preview(d, selected.line, selected.col, selected.path)
        end)
      end
    elseif use_preview then
      api.nvim_buf_set_lines(preview.buffer, 0, -1, false, {})
    end
  end)

  local function choose(command)
    command = command or "edit"

    local row = api.nvim_win_get_cursor(results.window)[1]
    local selected = partial_lines[row]

    close()

    -- Nothing was selected so just close
    if #partial_lines == 0 then
      return
    end

    -- TODO: Allow custom callback based on the selected data?
    api.nvim_command(string.format("%s %s", command, selected.path))
    if selected.line then
      local win = api.nvim_get_current_win()
      api.nvim_win_set_cursor(win, { selected.line, selected.col })
    end
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
      if cursor[1] < math.min(length, dimensions.height) then
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
    { type = "autocmd", event = "BufLeave", fn = close },

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
    return utils.str.trim(line:sub(3))
  end

  local function prompt_changed()
    -- Reset the cursor and scroll offset
    api.nvim_win_set_cursor(results.window, { 1, 0 })
    results.scroll = 1
    results.lines = {}

    -- clear the lines
    fill_results({})

    last_query = get_prompt(prompt.buffer)

    -- Stores info on the current finder
    local finder = {
      query = last_query,
      last_window = last_window,
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
      fill_results(results.lines)
    end

    local function finished()
      -- TODO: Should this be removed?
      -- if #results.lines == 0 then
      --   vim.schedule(function()
      --     fill_results({})
      --   end)
      -- end
    end

    -- Run the event loop
    async.loop({
      finder = finder,
      source = source,
      on_value = on_value,
      finished = finished,
    })
  end

  api.nvim_buf_attach(prompt.buffer, false, { on_lines = prompt_changed, on_detach = function() end })

  -- Ensure the prompt is the focused window
  api.nvim_set_current_win(prompt.window)
end

return find
