local state = {
  finder = nil
}

function state.close(cancel)
  if not state.finder then return end
  state.finder:close(cancel)
end

function state.search()
  if not state.finder then return end
  state.finder:search()
end

function state.run_mapping(map)
  if not state.finder then return end
  state.finder:run_mapping(map)
end

return state
