-- Creates a list of open buffers

local async = require("nvim-find.async")

local api = vim.api

local buffers = {}

local function buffer_filter(buf)
  if 1 ~= vim.fn.buflisted(buf) then
    return false
  end
  if not api.nvim_buf_is_loaded(buf) then
    return false
  end
  return true
end

local function get_buffer_list()
  local results = {}
  local bufs = api.nvim_list_bufs()
  for _, b in ipairs(bufs) do
    if buffer_filter(b) then
      table.insert(results, b)
    end
  end
  return results
end

local function get_alternate_name(window)
  return async.wait(function()
    return api.nvim_win_call(window, function()
      return vim.fn.bufname("#")
    end)
  end)
end

-- Assuming that the list of buffers is never more than 1000
-- there is no need to buffer the results here. Simply returning
-- the list should be responsive enough.
function buffers.run(state)
  local bufs = async.wait(get_buffer_list)

  -- build a pretty representation
  local bufs_res = {}
  for _, buffer in ipairs(bufs) do
    local name = async.wait(function() return vim.fn.bufname(buffer) end)
    local alternate_name = get_alternate_name(state.last_window)
    local info = async.wait(function() return vim.fn.getbufinfo(buffer)[1] end)

    local modified = " "
    if info.changed == 1 then
      modified = ""
    end

    local alternate = ""
    print(alternate_name)
    if name == alternate_name then
      -- alternate = ""
      alternate = " (alt)"
    end

    local result = string.format("%s %s%s", modified, name, alternate)
    table.insert(bufs_res, { result = result, path = name })
  end

  return bufs_res
end

return buffers
