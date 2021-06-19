-- local str = require("nvim-find.string-utils")
local uv = vim.loop

local job = {}

  -- uv.read_start(self.stdout, function(err, data)
  --   assert(not err, err)
  --   if data then
  --     local lines = str.split(data, "\n")
  --
  --     local start = 1
  --     if not self.last_was_complete then
  --       -- Concat last and first
  --       self.lines[#self.lines] = self.lines[#self.lines] .. lines[1]
  --       start = 2
  --     end
  --     for index=start,#lines do
  --       table.insert(self.lines, lines[index])
  --     end
  --
  --     self.last_was_complete = data == "\n"
  --   end
  -- end)

function job.spawn(cmd, args)
  local buffers = {
    stdout = "",
    stderr = "",
  }

  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local handle

  -- For cleanup when finished
  local function exit(_, _)
    uv.read_stop(stdout)
    uv.read_stop(stderr)
    uv.close(stdout)
    uv.close(stderr)
    uv.close(handle)
  end

  local function close()
    uv.process_kill(handle, uv.constants.SIGTERM)
  end

  local options = {
    args = args,
    stdio = { nil, stdout, stderr },
  }
  handle = uv.spawn(cmd, options, exit)

  uv.read_start(stdout, function(err, data)
    assert(not err, err)
    if data then
      buffers.stdout = buffers.stdout .. data
    end
  end)

  uv.read_start(stderr, function(err, data)
    assert(not err, err)
    if data then
      buffers.stderr = buffers.stderr .. data
    end
  end)

  -- Lua iterators are inner functions
  return function()
    if (handle and uv.is_active(handle)) or buffers.stdout ~= "" then
      local out = buffers.stdout
      local err = buffers.stderr
      buffers.stdout = ""
      buffers.stderr = ""
      return out, err, close
    else
      return nil
    end
  end
end

return job
