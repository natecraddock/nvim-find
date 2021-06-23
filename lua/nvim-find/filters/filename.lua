-- A filter designed to be particularly good at filename matching

local async = require("nvim-find.async")
local path = require("nvim-find.path")
local str = require("nvim-find.string-utils")

local file = {}

local function has_upper(value)
  return string.match(value, "%u") ~= nil
end

local DELIMITERS = "[-_.]"
local function has_delimiters(value)
  return string.match(value, DELIMITERS) ~= nil
end

-- Creates a filter that uses the given query
local function filename_filter(query, ignore_case, ignore_delimiters)
  query = str.trim(query)

  -- Should we ignore case?
  if ignore_case == nil then
    ignore_case = not has_upper(query)
  end

  -- Should we ignore delimiters?
  if ignore_delimiters == nil then
    ignore_delimiters = not has_delimiters(query)
  end

  local tokens = vim.split(query, " ", true)

  -- TODO: Are these cases ever actually needed? Can they be merged?

  -- Simple case when there is only one token in the query
  if #tokens == 1 then
    return function(value)
      value = value.result

      if ignore_case then value = value:lower() end
      if ignore_delimiters then value = value:gsub(DELIMITERS, "") end

      local filename = path.basename(value)
      return string.find(filename, query, 0, true)
    end
  end

  -- When there are more tokens after the first query do additional
  -- matching on the entire path
  return function(value)
    value = value.result

    if ignore_case then value = value:lower() end
    if ignore_delimiters then value = value:gsub(DELIMITERS, "") end

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

function file.run(source, ignore_case, ignore_delimiters)
  return function(finder)
    for results in async.iterate(source, finder) do
      if type(results) == "table" then
        coroutine.yield(vim.tbl_filter(filename_filter(finder.query, ignore_case, ignore_delimiters), results))
      else
        coroutine.yield(results)
      end
    end
  end
end

return file
