-- Search through the project with `rg`

local async = require("nvim-find.async")
local job = require("nvim-find.job")
local utils = require("nvim-find.utils")

local rg = {}

-- TODO: code duplication.. just make a map util?
local function map(lines, fn)
  for i, line in ipairs(lines) do
    lines[i] = fn(line)
  end
end

local function parse_vimgrep_line(grep_line)
  local filepath, row, column, match = string.match(grep_line, "(.-):(.-):(.-):(.*)")

  return {
    path = filepath,
    row = tonumber(row),
    col = tonumber(column),
    result = utils.str.trim(match),
  }
end

function rg.grep(finder)
  if finder.query == "" then
    return {}
  end

  for stdout, stderr, close in job.spawn("rg", {"--vimgrep", finder.query}) do
    if finder.is_closed() or stderr ~= "" then
      close()
      coroutine.yield(async.stopped)
    end

    if stdout ~= "" then
      local lines = vim.split(stdout:sub(1, -2), "\n", true)
      map(lines, parse_vimgrep_line)
      coroutine.yield(lines)
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
      local lines = vim.split(stdout:sub(1, -2), "\n", true)
      map(lines, function(line) return { result = line } end)
      coroutine.yield(lines)
    else
      coroutine.yield(async.pass)
    end
  end
end

return rg
