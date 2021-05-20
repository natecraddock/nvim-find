--String utility functions added to the built-in string table

-- Split a string into parts given a split delimiter
-- If no delimiter is given, space is used by default
-- Returns the parts of the string, the original is left unchanged.
function string:split(split_char)
  split_char = split_char or " "
  local str = self
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

-- Trims whitespace from the front and end of the string
-- Does not mutate the string, returns the trimmed version
function string:trim()
  local str = self
  -- Remove whitespace from the beginning of the string
  local start, ending = str:find("^%s*")
  if start then
    str = str:sub(ending + 1)
  end
  -- Remove whitespace from the end of the string
  local start, ending = str:find("%s*$")
  if start then
    str = str:sub(1, start - 1)
  end
  return str
end
