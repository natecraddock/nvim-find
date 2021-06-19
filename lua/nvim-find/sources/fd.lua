-- Find files in the current directory using the wonderful `fd` tool

local async = require("nvim-find.async")
local job = require("nvim-find.job")

local fd = {}

function fd.run(finder)
  for stdout, stderr, close in job.spawn("fd", {"-t", "f"}) do

    if finder.is_closed() then
      close()
      coroutine.yield(nil)
    end

    -- An error occurred, cancel
    if stderr ~= "" then
      close()
      coroutine.yield(nil)
    end

    if stdout ~= "" then
      local lines = vim.split(stdout:sub(1, -2), "\n", true)
      coroutine.yield(lines)
    else
      coroutine.yield(async.pass)
    end
  end
end

return fd
