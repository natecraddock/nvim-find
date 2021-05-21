-- String utility functions

local string_utils = {}

-- Split a string into parts given a split delimiter
-- If no delimiter is given, space is used by default
-- Returns the parts of the string, the original is left unchanged.
function string_utils.split(str, split_char)
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

-- Returns a string with whitespace trimmed from the front and end of
-- the string.
function string_utils.trim(str)
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

return string_utils
