-- Path functions

local fs = require('nvim-find.fs')
local str = require("nvim-find.string-utils")

local path = {}

-- Return the basename of a path
-- If the path ends in a file, the name is returned
-- If the path ends in a directory followed by a separator then
-- the final directory is returned.
function path.basename(path_str)
  local parts = str.split(path_str, fs.sep)
  return parts[#parts]
end

-- Given a path, split into name and extension pair
-- If there is no name or extension (like .bashrc) then the
-- full name is returned as the name with an empty extension.
function path.splitext(name)
  if name:sub(1, 1) == "." then
    return name, ""
  end

  local parts = str.split(name, "%.")
  return parts[1], parts[2]
end

return path
