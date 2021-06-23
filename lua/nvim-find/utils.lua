-- General utility functions useful throughout nvim-find

local utils = {}
utils.fn = {}
utils.path = {}
utils.str = {}

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

-- Functional-programming style utilities

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

return utils
