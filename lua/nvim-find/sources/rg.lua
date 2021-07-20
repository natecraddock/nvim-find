-- Search through the project with `rg`

local async = require("nvim-find.async")
local job = require("nvim-find.job")

local rg = {}

function rg.grep(state)
  if state.query == "" then
    return {}
  end

  for stdout, stderr, close in job.spawn("rg", {"--vimgrep", "--smart-case", state.query}) do
    if state.closed() or state.changed() or stderr ~= "" then
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

function rg.files(state)
  for stdout, stderr, close in job.spawn("rg", {"--files"}) do
    if state.closed() or state.changed() or stderr ~= "" then
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
