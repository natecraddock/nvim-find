-- A filter designed to be particularly good at filename matching

local async = require("nvim-find.async")
local utils = require("nvim-find.utils")

local file = {}

local function has_upper(value)
  return string.match(value, "%u") ~= nil
end

local DELIMITERS = "[-_.]"
local function has_delimiters(value)
  return string.match(value, DELIMITERS) ~= nil
end

-- Creates a filter that uses the given query
local function filename_filter(query, ignore_case, ignore_delimiters, full_path)
  -- Should we ignore case?
  if ignore_case == nil then
    ignore_case = not has_upper(query)
  end

  -- Should we ignore delimiters?
  if ignore_delimiters == nil then
    ignore_delimiters = not has_delimiters(query)
  end

  local tokens = vim.split(query, " ", true)

  -- When there are more tokens after the first query do additional
  -- matching on the entire path
  return function(value)
    value = value.result

    if ignore_case then value = value:lower() end
    if ignore_delimiters then value = value:gsub(DELIMITERS, "") end

    local filename
    if full_path then
      filename = value
    else
      filename = utils.path.basename(value)
    end
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
    local query = utils.str.trim(finder.query)

    local had_results = false
    for results in async.iterate(source, finder) do
      if type(results) == "table" then
        local filtered = vim.tbl_filter(filename_filter(query, ignore_case, ignore_delimiters), results)
        if #filtered > 0 then had_results = true end

        coroutine.yield(filtered)
      else
        coroutine.yield(results)
      end
    end

    -- No results, fall back on full path match
    if not had_results then
      for results in async.iterate(source, finder) do
        if type(results) == "table" then
          coroutine.yield(vim.tbl_filter(filename_filter(query, ignore_case, ignore_delimiters, true), results))
        else
          coroutine.yield(results)
        end
      end
    end
  end
end

return file
