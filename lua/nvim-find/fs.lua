-- File System Utilities

local uv = vim.loop

local fs = {}

local Set = require("nvim-find.set")
local str = require("nvim-find.string-utils")

-- System-specific path separator
fs.sep = package.path:sub(1, 1)

--[[
-- It seems like doing .gitignore parsing on large (n > 100000) projects is very computationally
-- expensive in lua. Other programs like find can handle it like a champ, so I think a better alg
-- is to defer to fd or some other program, then fall back on a simple and fast lua solution.
--
-- For Lua:
-- * The code below works great, and some very basic gitignore can be done like:
--   * Ignoring the .git or other source folders .vscode, really any hidden folder
--]]--

local function exists(path)
  local stats = uv.fs_stat(path) or {}
  return not vim.tbl_isempty(stats)
end

local function read(path)
  local fd = assert(uv.fs_open(path, "r", 438))
  local stat = assert(uv.fs_fstat(fd))
  local data = assert(uv.fs_read(fd, stat.size, 0))
  assert(uv.fs_close(fd))

  return data
end

local function escape_pattern(pattern)
  pattern = pattern:gsub("%.", "%%.")  -- Replace . with %. to match literal .
  pattern = pattern:gsub("%*", "%.%*") -- Replace * with .* to match wildcard
  if pattern:sub(1, 1) == "/" then
    pattern = pattern:gsub("^/", "%^")   -- Match at beginning for absolute ignore rules
  else
    pattern = "/" .. pattern
  end
  return pattern
end

local function read_gitignore(gitignore)
  local patterns = Set:new()
  gitignore:gsub("\r", "")
  local lines = str.split(gitignore, "\n")
  for _, line in ipairs(lines) do
    -- Ignore blanks and comments
    if line == "" or line:sub(1, 1) == "#" then
    else
      -- Strip trailing comments
      line = line:gsub("%s+#.*$", "")
      patterns:add(escape_pattern(line))
    end
  end
  return patterns
end

local function setignore(path, ignored)
  -- Merge the two tables
  local gitignore_path = path .. fs.sep .. ".gitignore"

  if exists(gitignore_path) then
    local gitignore = read(gitignore_path)
    local ig = read_gitignore(gitignore)
    ignored = ignored:union(ig)
  end

  return { path = path, ignored = ignored }
end

local function shouldignore(path, ignored, type)
  if type == "directory" then path = path .. fs.sep end
  for pattern, _ in pairs(ignored) do
    if path:sub(2):match(pattern) then
      return true
    end
  end
  return false
end

-- Walk a set of paths and execute a callback at each file.
-- Stats are returned in a table
local function walk(paths, callback)
  local count = 0

  -- Each item in the unvisited table is a table containing the path
  -- and any directories to be ignored
  local unvisited = {}
  for _, path in ipairs(paths) do
    table.insert(unvisited, setignore(path, Set:new()))
    callback(path, "directory")
  end

  repeat
    local dir = table.remove(unvisited, 1)
    local current_dir = uv.fs_scandir(dir.path)
    if current_dir then
      while true do
        local name, type = uv.fs_scandir_next(current_dir)
        if name == nil then break end

        local path = dir.path .. fs.sep .. name

        -- Check if this should be ignored
        if not shouldignore(path, dir.ignored, type) then
          if type == "directory" then
            table.insert(unvisited, setignore(path, dir.ignored))
            callback(path, type)
          else
            callback(path, type)
          end
          count = count + 1
        end
      end
    end
  until #unvisited == 0

  return { count = count }
end

function fs.walkdir(paths)
  local list = {}

  paths = paths or { "." }

  local cb = function(path, type)
    if type == "file" then
      table.insert(list, path:sub(3))
    end
  end

  local stats = walk(paths, cb)

  return list
end

-- Attach a watch to each directory in a path
function fs.watch(paths, notify_callback)
  local handles = {}

  paths = paths or { "." }

  local cb = function(path, type)
    if type == "directory" then
      local fs_handle = uv.new_fs_event()
      uv.fs_event_start(fs_handle, path, {}, notify_callback)
      table.insert(handles, fs_handle)
    end
  end

  walk(paths, cb)

  return handles
end

return fs
