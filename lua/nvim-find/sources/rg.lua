-- Search through the project with `rg`

local async = require("nvim-find.async")
local job = require("nvim-find.job")

local rg = {}

function rg.grep(finder)
  if finder.query == "" then
    return {}
  end

  for stdout, stderr, close in job.spawn("rg", {"--vimgrep", "--smart-case", finder.query}) do
    if finder.is_closed() or stderr ~= "" then
      close()
      coroutine.yield(async.stopped)
    end

    if stdout ~= "" then
      coroutine.yield({ as_string = stdout })
    else
      coroutine.yield(async.pass)
    end
  end
end

function rg.files(finder)
  for stdout, stderr, close in job.spawn("rg", {"--files"}) do
    if finder.is_closed() or stderr ~= "" then
      close()
      coroutine.yield(async.stopped)
    end

    if stdout ~= "" then
      coroutine.yield({ as_string = stdout })
    else
      coroutine.yield(async.pass)
    end
  end
end

return rg
