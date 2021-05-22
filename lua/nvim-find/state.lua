local state = {
  finder = nil
}

function state.run_mapping(map)
  if not state.finder then return end
  state.finder:run_mapping(map)
end

return state
