local finder = require("nvim-find.finder")

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

local function open_file(path, split)
  local command = "edit"
  if split then command = split end
  vim.cmd(string.format(":%s %s", command, path))
end

local events = {
  { key = "<cr>", type = "select", callback = function(selected) open_file(selected, "buffer") end },
  { key = "<c-s>", type = "select", callback = function(selected) open_file(selected, "split") end },
  { key = "<c-v>", type = "select", callback = function(selected) open_file(selected, "vsplit") end },
  { key = "<c-t>", type = "select", callback = function(selected) open_file(selected, "tabedit") end },
}

function buffers.open()
  finder.Finder:new({
    source = get_buffer_list,
    events = events,
  }):open()
end

return buffers
