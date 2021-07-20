-- A simple string matching filter

local async = require("nvim-find.async")

local simple = {}

local function has_upper(value)
  return string.match(value, "%u") ~= nil
end

local function simple_filter(query)
  -- Should we ignore case?
  local ignore_case = not has_upper(query)

  return function(value)
    value = value.result
    if ignore_case then value = value:lower() end
    return string.find(value, query, 0, true)
  end
end

function simple.run(source)
  return function(state)
    for results in async.iterate(source, state) do
      if type(results) == "table" then
        coroutine.yield(vim.tbl_filter(simple_filter(state.query), results))
      else
        -- TODO: Is this case needed? Is it handled by async.iterate already?
        coroutine.yield(results)
      end
    end
  end
end

return simple
