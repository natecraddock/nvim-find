-- Find files in the current directory using the wonderful `fd` tool

local async = require("nvim-find.async")
local job = require("nvim-find.job")

local fd = {}

function fd.run(finder)
  for stdout, stderr, close in job.spawn("fd", {"-t", "f"}) do

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

return fd
