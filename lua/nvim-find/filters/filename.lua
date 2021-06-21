-- A filter designed to be particularly good at filename matching

local async = require("nvim-find.async")
local path = require("nvim-find.path")
local str = require("nvim-find.string-utils")

local file = {}

-- TODO: ignore delimiters?

local function has_upper(value)
  return string.match(value, "%u") ~= nil
end

-- Creates a filter that uses the given query
local function filename_filter(query)
  query = str.trim(query)

  -- Should we ignore case?
  local ignore_case = not has_upper(query)

  local tokens = vim.split(query, " ", true)

  -- Simple case when there is only one token in the query
  if #tokens == 1 then
    return function(value)
      if ignore_case then value = value:lower() end
      local filename = path.basename(value)
      return string.find(filename, query, 0, true)
    end
  end

  -- When there are more tokens after the first query do additional
  -- matching on the entire path
  return function(value)
    if ignore_case then value = value:lower() end

    local filename = path.basename(value)
    if not string.find(filename, tokens[1], 0, true) then
      return false
    end

    -- The hope is that the previous check will eliminate most of the matches
    -- so any work afterwords can be slightly more complex because it is only
    -- running on a subset of the input

    -- A match was found, try remaining tokens on full path
    for i=2,#tokens do
      if not string.find(value, tokens[i], 0, true) then
        return false
      end
    end

    return true
  end
end

function file.run(source)
  return function(finder)
    for results in async.iterate(source, finder) do
      if type(results) == "table" then
        coroutine.yield(vim.tbl_filter(filename_filter(finder.query), results))
      else
        coroutine.yield(results)
      end
    end
  end
end

return file
