-- A filter that caches the results of it's source so later
-- iterations can run quicker and potentially make fewer
-- subprocess calls for efficiency.

local async = require("nvim-find.async")

local cache = {}

local buffer_size = 1000

local function slice(list, first, last)
  local l = {}

  for i = first, last or #list do
    table.insert(l, list[i])
  end

  return l
end

-- TODO: Allow passing in a table for an external cache
-- then we could store the results of a large file find somewhere,
-- then invalidate them on a file change? idk it sounds like a decent idea
function cache.run(source)
  local c = {}

  -- In addition to caching the results, we also need to track if
  -- all of the lines were indeed received from the source, otherwise
  -- the cache is only storing a partial set of the results!
  local full = false

  return function(finder)
    -- When full the cache can be large. Returning the entire cache can be
    -- really slow for later filters, so it's best to buffer it when large.
    if full then
      -- In the case the buffer is small don't add extra overhead
      if #c <= buffer_size then
        return c
      end

      local index = 1

      -- TODO: Extract into general purpose buffer filter
      while index < #c do
        local e = math.min(#c, index + buffer_size)
        coroutine.yield({unpack(c, index, e)})
        index = index + buffer_size
      end
    else
      for results in async.iterate(source, finder, true) do
        if results == async.completed then coroutine.yield({}) end

        -- TODO: This is part of EVERY filter and that's bad
        if finder.is_closed() then
          coroutine.yield(async.stopped)
        end

        if results == async.stopped then
          coroutine.yield(async.stopped)
          -- return async.canceled
        end

        for _, val in ipairs(results) do
          table.insert(c, val)
        end
        coroutine.yield(results)
      end

      full = true
      print("filled cache")
    end
  end
end

return cache
