-- General utility functions useful throughout nvim-find

local uv = vim.loop

local utils = {
  fn = {},
  path = {},
  str = {},
  fs = {},
}

function utils.notify(msg)
  vim.api.nvim_echo({{ "nvim-find: " .. msg, "MsgArea" }}, true, {})
end

-- attempt to require
function utils.try_require(name)
  return pcall(function() return require(name) end)
end

-- wraps a function that is scheduled to run
function utils.scheduled(fn)
  local args_cache = nil
  return function(...)
    local args = { ... }

    -- update args and exit if already scheduled
    if args_cache then
      args_cache = args
      return
    end

    args_cache = args

    vim.schedule(function()
      fn(unpack(args_cache))

      -- allow running again with updated args
      args_cache = nil
    end)
  end
end

-- Thanks plenary devs!
utils.path.sep = (function()
  if jit then
    local os = string.lower(jit.os)
    if os == "linux" or os == "osx" or os == "bsd" then
      return "/"
    else
      return "\\"
    end
  else
    return package.config:sub(1, 1)
  end
end)()

-- Functional-programming style utilities and other useful functions

-- A map that returns a new list
function utils.fn.map(list, fn)
  local new_list = {}
  for _, item in ipairs(list) do
    table.insert(new_list, fn(item))
  end
  return new_list
end

-- A map that mutates the given list
function utils.fn.mutmap(list, fn)
  for i, item in ipairs(list) do
    list[i] = fn(item)
  end
end

function utils.fn.slice(list, i, j)
  local new_list = {}
  for index=i,j do
    table.insert(new_list, list[index])
  end
  return new_list
end

-- join table b at the end of table a
function utils.fn.mutextend(a, b)
  for _, value in ipairs(b) do
    table.insert(a, value)
  end
end

function utils.fn.copy(list)
  local new_list = {}
  for key, value in pairs(list) do
    new_list[key] = value
  end
  return new_list
end

-- clamp within a range (inclusive)
function utils.fn.clamp(val, a, b)
  if val < a then
    return a
  elseif val > b then
    return b
  end
  return val
end

-- Path related utilities

-- Return the basename of a path
-- If the path ends in a file, the name is returned
-- If the path ends in a directory followed by a separator then
-- the final directory is returned.
function utils.path.basename(path_str)
  local parts = utils.str.split(path_str, utils.path.sep)
  return parts[#parts]
end

-- Given a path, split into name and extension pair
-- If there is no name or extension (like .bashrc) then the
-- full name is returned as the name with an empty extension.
function utils.path.splitext(name)
  if name:sub(1, 1) == "." then
    return name, ""
  end

  local parts = utils.str.split(name, "%.")
  return parts[1], parts[2]
end

-- String related utilities

-- Split a string into parts given a split delimiter
-- If no delimiter is given, space is used by default
-- Returns the parts of the string, the original is left unchanged.
function utils.str.split(str, split_char)
  split_char = split_char or " "
  local parts = {}
  repeat
    local start, _ = str:find(split_char)
    -- Last match
    if not start then
      table.insert(parts, str)
      str = ""
    else
      table.insert(parts, str:sub(1, start - 1))
      str = str:sub(start + 1)
    end
  until #str == 0
  return parts
end

-- Join the elements of the table delimited by str.
function utils.str.join(str, list)
  local result = ""
  if #list == 1 then
    return list[1]
  end

  result = list[1]
  for i = 2,#list do
    result = result .. str .. list[i]
  end

  return result
end

-- Returns a string with whitespace trimmed from the front and end of
-- the string.
function utils.str.trim(str)
  -- Remove whitespace from the beginning of the string
  local start, ending = str:find("^%s*")
  if start then
    str = str:sub(ending + 1)
  end
  -- Remove whitespace from the end of the string
  start, ending = str:find("%s*$")
  if start then
    str = str:sub(1, start - 1)
  end
  return str
end

function utils.fs.read(path, fn)
  uv.fs_open(path, "r", 438, function(_, fd)
    uv.fs_fstat(fd, function(_, stat)
      -- TODO: Read this in chunks?
      uv.fs_read(fd, stat.size, 0, function(_, data)
        uv.fs_close(fd, function(_)
          -- If we get here then return the data
          return fn(data)
        end)
      end)
    end)
  end)
end

return utils
