-- A filter to join two or more sources

local async = require("nvim-find.async")

local join = {}

function join.run(...)
  local sources = {...}
  assert(#sources > 1, "the join filter expects more than one source")

  return function(state)
    for _, source in ipairs(sources) do
      for results in async.iterate(source, state) do
        coroutine.yield(results)
      end
    end
  end
end

return join
