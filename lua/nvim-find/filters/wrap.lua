-- Wrap filter. All sources should be wrapped by this filter

local async = require("nvim-find.async")
local utils = require("nvim-find.utils")

local wrap = {}

function wrap.run(source, fn)
  fn = fn or function(lines)
    utils.fn.mutmap(lines, function(result)
      return { result = result, path = result }
    end)
    return lines
  end

  return function(state)
    -- Store the partial contents of the last line
    local last_line_partial = ""

    for results in async.iterate(source, state) do
      if type(results) == "table" then
        if results.as_string ~= nil then
          results = results.as_string
          -- The results are one large string to be split
          local lines = vim.split(results, "\n", true)

          -- If there is partial portion from last time concat to the first line
          if last_line_partial ~= "" then
            lines[1] = last_line_partial .. lines[1]
            last_line_partial = ""
          end

          -- If the last line was incomplete then the last item in the array
          -- won't be an empty string.
          if lines[#lines] ~= "" then
            last_line_partial = lines[#lines]
          end

          -- Never include the last line because it is either partial or ""
          local partial = utils.fn.slice(lines, 1, #lines - 1)
          partial = fn(partial)
          coroutine.yield(partial)
        else
          results = fn(results)
          coroutine.yield(results)
        end
      else
        -- TODO: is this case needed?
        coroutine.yield(results)
      end
    end
  end
end

return wrap
