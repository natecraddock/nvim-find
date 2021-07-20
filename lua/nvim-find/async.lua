-- Code to help the finders run asynchronously

local utils = require("nvim-find.utils")

local async = {}

local uv = vim.loop

-- A constant used to yield to other coroutines
async.pass = {}

-- A constant used to inform of a canceled coroutine
async.stopped = {}

-- A constant used to inform of a source run to completion
async.completed = {}

-- Await some functions result
function async.wait(fn)
  -- Return the function to the main event loop
  -- The main loop will schedule the execution and
  -- resume the coroutine when ready.
  local state, result = coroutine.yield(fn)
  return result
end

local function resume(thread, state, notify, value)
    local _, result = coroutine.resume(thread, state, value)

    if state.is_closed() or result == async.stopped then
      return async.stopped
    end

    if type(result) == "function" then
      return resume(thread, state, notify, async.wait(result))
    end

    -- The source finished iterating
    if notify and result == nil then
      coroutine.yield(async.completed)
    elseif result == async.stopped then
      coroutine.yield(async.stopped)
    end

    return result
end

function async.iterate(source, state, notify)
  local thread = coroutine.create(source)
  return function()
    if coroutine.status(thread) ~= "dead" then
      return resume(thread, state, notify)
    end
  end
end

-- Loop to run when a finder is active
-- This is the lowest point at which coroutines are handled. Some are
-- caught at deeper layers, but if a source or filter doesn't handle a
-- case it will end up here.
function async.loop(config)
  local state = config.state
  local idle = uv.new_idle()
  local thread = coroutine.create(config.source)

  local deferred = {
    running = false,
    result = nil,
  }

  function deferred.run(fn)
    deferred.running = true
    vim.schedule(function()
      deferred.result = fn()
      deferred.running = false
    end)
  end

  local function stop()
    uv.idle_stop(idle)
  end

  if state.is_closed() then
    return
  end

  uv.idle_start(idle, function()
    if deferred.running then return end

    if coroutine.status(thread) ~= "dead" then
      -- Resume the main thread or a deeper coroutine
      local _, value = coroutine.resume(thread, state, deferred.result)

        if state.is_closed() then
          stop()
        else

        -- Must catch this case
        -- Could we maybe use iterate here too?
        if value == nil then
          stop()
        elseif type(value) == "function" then
          -- Schedule the function to be run
          deferred.run(value)
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
