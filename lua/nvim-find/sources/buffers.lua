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
      table.insert(results, vim.fn.bufname(b))
    end
  end
  return results
end

-- Assuming that the list of buffers is never more than 1000
-- there is no need to buffer the results here. Simply returning
-- the list should be responsive enough.
function buffers.run(finder)
  return async.wait(get_buffer_list)
end

return buffers
