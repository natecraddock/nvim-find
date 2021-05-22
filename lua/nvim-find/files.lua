local finder = require("nvim-find.finder")
local fs = require("nvim-find.fs")
local path = require("nvim-find.path")
local set = require("nvim-find.set")
local str = require("nvim-find.string-utils")

local files = {}

local uv = vim.loop

local source = {
  list = {},
  file_finder = nil,
  handles = {},
}

local filter = {
  index = nil
}

function source:cleanup_handles()
  for _, handle in ipairs(self.handles) do
    uv.fs_event_stop(handle)
  end
  source:watch_paths()
end

function source:watch_paths()
  local callback = vim.schedule_wrap(function()
    self:find_files()
    self:cleanup_handles()
    filter.index = nil
  end)

  self.handles = fs.watch({"."}, callback)
end

function source:find_files()
  if not self.file_finder then
    if vim.fn.executable("fd") then
      self.file_finder = function() return vim.fn.systemlist("fd -t f") end
    else
      self.file_finder = fs.walkdir
    end
    self:watch_paths()
  end

  self.list = self:file_finder()
end

function source:get()
  if #self.list == 0 then
    self:find_files()
  end
  return self.list
end

local Index = { }

function Index:new()
  local index = {}
  setmetatable(index, self)
  self.__index = self
  return index
end

function Index:add(key, value)
  if self[key] then
    self[key]:add(value)
  else
    self[key] = set:new({ value })
  end
end

function Index:find(key, sloppy)
  local finder = nil
  if sloppy then
    finder = function(a)
      return string.find(a:gsub("[-_.]", ""), key, 1, true)
    end
  else
    finder = function(a, b)
      return string.find(a, key, 1, true)
    end
  end

  local matches = {}
  for k, v in pairs(self) do
    if finder(k) then
      for p, _ in pairs(v) do
        table.insert(matches, p)
      end
    end
  end
  if #matches == 0 then
    return nil
  end
  return matches
end

local function check_other_tokens(str, tokens, skip)
  if #tokens == 1 then return true end
  for index, token in ipairs(tokens) do
    if index ~= skip then
      if not string.find(str, token, 1, true) then
        return false
      end
    end
  end
  return true
end

function filter:run(input, query)
  if not self.index then
    self.index = Index:new()
    for _, p in ipairs(input) do
      local basename = path.basename(p)
      -- local name, _ = path.splitext(basename)
      self.index:add(basename:lower(), p)
    end
  end

  if #query == 0 then
    return input
  end

  -- Split query into tokens
  query = str.split(query)

  local matches = {}
  for i, token in ipairs(query) do
    local sloppy = not string.find(token, "[-_.]")
    local m = self.index:find(token, sloppy)
    if m then
      for _, match in ipairs(m) do
        matches[match] = i
      end
    end
  end

  local matches_flattened = {}
  for match, query_index in pairs(matches) do
    if check_other_tokens(match, query, query_index) then
      table.insert(matches_flattened, match)
    end
  end

  return matches_flattened
end

local files_finder = nil

local function open_file(path, split)
  local command = "edit"
  if split then command = split end
  vim.cmd(string.format(":%s %s", command, path))
end

local actions = {
  { key = "<cr>", type = "accept", callback = function(selected) open_file(selected) end },
  { key = "<c-s>", type = "accept", callback = function(selected) open_file(selected, "split") end },
  { key = "<c-v>", type = "accept", callback = function(selected) open_file(selected, "vsplit") end },
}

function files.open()
  -- Create the finder on the first run
  if not files_finder then
    files_finder = finder:new({
      source = source,
      filter = filter,
      actions = actions,
    })
  end

  files_finder:open()
end

return files
