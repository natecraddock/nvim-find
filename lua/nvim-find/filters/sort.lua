-- A filter that sorts the results by length

local async = require("nvim-find.async")

local sort = {}

local function sort_by_length(to_sort)
  table.sort(to_sort, function(a, b)
    return #a < #b
  end)
end

function sort.run(source, n)
  -- Too much sorting can slow down filters
  -- Only sort at most the first 100 results by default.
  n = n or 100

  return function(finder)
    -- Sorting requires a complete list
    local to_sort = {}
    local sorted = false

    for results in async.iterate(source, finder) do
      if type(results) == "table" then
        if sorted then
          coroutine.yield(results)
        else
          for _, val in ipairs(results) do
            table.insert(to_sort, val)
          end

          -- If enough results have come, run the sort
          if #to_sort >= n then
            local first = { unpack(to_sort, 1, n) }
            local second = { unpack(to_sort, n + 1) }

            -- Yield the first n results sorted
            sort_by_length(first)
            coroutine.yield(first)

            -- If there were others iterated already, yield these too
            if #second ~= 0 then
              coroutine.yield(second)
            end

            sorted = true
          else
            -- Allow other tasks to run
            coroutine.yield(async.pass)
          end
        end
      else
        coroutine.yield(results)
      end
    end

    -- If we are here and have not sorted then there were less
    -- than n total results. Sort now and return.
    if not sorted then
      sort_by_length(to_sort)
      return to_sort
    end

  end
end

return sort
