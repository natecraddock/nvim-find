-- Search through the project with `rg`

local async = require("nvim-find.async")
local job = require("nvim-find.job")

local rg = {}

function rg.run(finder)
  if finder.query == "" then
    return {}
  end

  for stdout, stderr, close in job.spawn("rg", {"--vimgrep", finder.query}) do
    if finder.is_closed() then
      close()
      coroutine.yield(async.stopped)
    end

    -- An error occurred, cancel
    if stderr ~= "" then
      close()
      coroutine.yield(async.stopped)
    end

    if stdout ~= "" then
      local lines = vim.split(stdout:sub(1, -2), "\n", true)
      coroutine.yield(lines)
    else
      coroutine.yield(async.pass)
    end
  end
end

return rg
