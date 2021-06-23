-- Wrap filter. All sources should be wrapped by this filter

local async = require("nvim-find.async")
local utils = require("nvim-find.utils")

local wrap = {}

function wrap.run(source, fn)
  fn = fn or function(result) return { result = result } end

  return function(finder)
    for results in async.iterate(source, finder) do
      if type(results) == "table" then
        utils.fn.mutmap(results, fn)
        coroutine.yield(results)
      else
        -- TODO: is this case needed?
        coroutine.yield(results)
      end
    end
  end
end

return wrap
