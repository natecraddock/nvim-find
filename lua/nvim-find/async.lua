-- Code to help the finders run asynchronously

local async = {}

local uv = vim.loop

-- A constant used to yield to other coroutines
async.pass = {}

-- A constant used to inform of a canceled coroutine
async.stopped = {}

-- A constant used to inform of a source run to completion
async.completed = {}

function async.wait()
end

function async.iterate(source, finder, notify)
  local thread = coroutine.create(source)
  return function()
    if coroutine.status(thread) ~= "dead" then
      local _, value = coroutine.resume(thread, finder)

      if value == async.stopped then
        coroutine.yield(async.stopped)
      end

      -- The source finished iterating
      if notify and value == nil then
        coroutine.yield(async.completed)
      elseif value == nil then
        coroutine.yield(async.stopped)
      end

      return value
    end
  end
end

-- Loop to run when a finder is active
-- This is the lowest point at which coroutines are handled. Some are
-- caught at deeper layers, but if a source or filter doesn't handle a
-- case it will end up here.
function async.loop(config)
  local finder = config.finder
  local idle = uv.new_idle()
  local thread = coroutine.create(config.source)

  local function stop()
    uv.idle_stop(idle)
  end

  if finder.is_closed() then
    return
  end

  uv.idle_start(idle, function()
    if coroutine.status(thread) ~= "dead" then
      -- Resume the main thread or a deeper coroutine
      local _, value = coroutine.resume(thread, finder)

      if finder.is_closed() then
        stop()
      else
        -- Must catch this case
        -- Could we maybe use iterate here too?
        if value == nil then
          stop()
        elseif type(value) == "function" then
          print(vim.inspect(value), value)
        elseif value == async.stopped then
          stop()
        elseif value == async.pass then
        else
          config.on_value(value)
        end
      end

    else
      -- The main thread is finished
      stop()
    end
  end)
end

return async
