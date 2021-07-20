-- A filter designed to be particularly good at filename matching

local async = require("nvim-find.async")
local config = require("nvim-find.config")
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
local function filename_filter(query, ignore_case, ignore_delimiters)
  -- Should we ignore case?
  if ignore_case == nil then
    ignore_case = not has_upper(query)
  end

  -- Should we ignore delimiters?
  if ignore_delimiters == nil then
    ignore_delimiters = not has_delimiters(query)
  end

  local tokens = vim.split(query, " ", true)

  local ignore_patterns = {}
  for _, pat in ipairs(config.files.ignore) do
    pat = pat:gsub("%.", "%%.")
    pat = pat:gsub("%*", "%.%*")
    table.insert(ignore_patterns, "^" .. pat .. "$")
  end
  local function should_ignore(value)
    for _, pat in ipairs(ignore_patterns) do
      if value:match(pat) then return true end
    end
    return false
  end

  -- When there are more tokens after the first query do additional
  -- matching on the entire path
  return function(line)
    local value = line.result

    -- first check if the path should be ignored
    if should_ignore(value) then return end

    if ignore_case then value = value:lower() end
    if ignore_delimiters then value = value:gsub(DELIMITERS, "") end

    local filename = utils.path.basename(value)
    line.rank = 1
    if not string.find(filename, tokens[1], 0, true) then
      -- retry on full path
      if not string.find(value, tokens[1], 0, true) then
        return false
      end

      -- Did match on the full path
      line.rank = 0
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
  return function(state)
    local query = utils.str.trim(state.query)

    local had_results = false
    for results in async.iterate(source, state) do
      if type(results) == "table" then
        local filtered = vim.tbl_filter(filename_filter(query, ignore_case, ignore_delimiters), results)
        if #filtered > 0 then had_results = true end

        coroutine.yield(filtered)
      else
        coroutine.yield(results)
      end
    end
  end
end

return file
