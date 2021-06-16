local mappings = {}

local api = vim.api

local mappings_table = {}

function mappings.clear()
  mappings_table = {}
end

function mappings.run(num)
  mappings_table[num]()
end

local function register(fn)
  table.insert(mappings_table, fn)
  return #mappings_table
end

local function register_keymap(buffer, key, fn)
  local num = register(fn)

  local options = { nowait = true, silent = true, noremap = true }
  local rhs = string.format("<cmd>:lua require('nvim-find.mappings').run(%s)<cr>", num)
  api.nvim_buf_set_keymap(buffer, "i", key, rhs, options)
end

local function register_autocmd(buffer, event, fn)
  local num = register(fn)

  local cmd = string.format("autocmd %s <buffer=%s> :lua require('nvim-find.mappings').run(%s)",
                            event,
                            buffer,
                            num)
  api.nvim_command(cmd)
end

-- Set the autocommands and keybindings for the finder
function mappings.add(buffer, mapping)
  if mapping.type == "keymap" then
    register_keymap(buffer, mapping.key, mapping.fn)
  elseif mapping.type == "autocmd" then
    register_autocmd(buffer, mapping.event, mapping.fn)
  end
end

return mappings
