-- Find files in the current directory using the wonderful `fd` tool

local function make_results(lines)
  for i, line in ipairs(lines) do
    lines[i] = { result = line }
  end
end

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
      local lines = vim.split(stdout:sub(1, -2), "\n", true)
      make_results(lines)
      coroutine.yield(lines)
    else
      coroutine.yield(async.pass)
    end
  end
end

return fd
