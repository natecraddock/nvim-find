-- A set-like wrapper around tables

local Set = {
  items = {}
}

function Set:new(list)
  local set = { items = {} }
  if list then
    for _, value in ipairs(list) do
      set.items[value] = 1
    end
  end
  setmetatable(set, self)
  self.__index = self
  return set
end

function Set:add(item)
  self.items[item] = 1
end

function Set:contains(item)
  return self.items[item] ~= nil
end

function Set:union(other)
  local set = vim.deepcopy(self)
  setmetatable(set, getmetatable(self))

  for key, _ in pairs(other) do
    set[key] = 1
  end
  return set
end

return Set
