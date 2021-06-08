local str = require("nvim-find.string-utils")
local uv = vim.loop

local Job = {
  handle = nil,
  pid = nil,
  cmd = nil,
  callback = nil,
  stdout = nil,
  stderr = nil,
  lines = {},
  last_was_complete = true,
}

-- TODO: potentially replace with vim jobstart
function Job:new(cmd, args, callback)
  local job = {}
  setmetatable(job, self)
  self.__index = self

  job.handle = nil
  job.pid = nil
  job.cmd = cmd
  job.args = args
  job.callback = callback
  job.lines = {}
  job.last_was_complete = true

  return job
end

function Job:start()
  local stdout_callback = function(chan_id, data, name)
    -- self.stdout = data
  end

  local callback_wrapper = function(code, signal)
    if self.handle == nil then
      return
    end
    self.handle = nil
    self.pid = nil
    self.callback(self.lines)
  end

  self.stdout = uv.new_pipe(false)
  self.stderr = uv.new_pipe(false)

  local options = {
    stdio = {nil, self.stdout, self.stderr},
    command = self.cmd,
    args = self.args
  }

  local handle, pid = uv.spawn(self.cmd, options, callback_wrapper)

  self.handle = handle
  self.pid = pid

  uv.read_start(self.stdout, function(err, data)
    assert(not err, err)
    if data then
      local lines = str.split(data, "\n")

      local start = 1
      if not self.last_was_complete then
        -- Concat last and first
        self.lines[#self.lines] = self.lines[#self.lines] .. lines[1]
        start = 2
      end
      for index=start,#lines do
        table.insert(self.lines, lines[index])
      end

      self.last_was_complete = data == "\n"
    end
  end)

  return true
end

function Job:stop()
  if self.handle == nil then
    return
  end

  if uv.process_kill(self.handle, "sigint") ~= 0 then
    print("failed to kill")
  end

  self.handle = nil
end

return Job
