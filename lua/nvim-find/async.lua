-- Code to help the finders run asynchronously

local async = {}

local uv = vim.loop

-- A constant used to yield to other coroutines
async.pass = {}

function async.wait()
end

function async.iterate(source, finder)
  local thread = coroutine.create(source)
  return function()
    if coroutine.status(thread) ~= "dead" then
      local _, value = coroutine.resume(thread, finder)
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
        if value == nil then
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
