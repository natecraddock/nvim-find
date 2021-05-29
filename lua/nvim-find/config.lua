local config = {}

local defaults = {
  -- File paths to be ignored when walking directories (nvim-find.fs.walk)
  ignore = { ".git", ".hg", "__pycache__", "node_modules" }
}

local user = {}

-- Store user prefs for overriding the default preferences
function config.setup(prefs)
  user = prefs
end

-- Return the named config setting giving preference to user config
function config.get(config_name)
  if user[config_name] ~= nil then
    return user[config_name]
  else
    return defaults[config_name]
  end
end

return config
