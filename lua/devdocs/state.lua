local DEVDOCS_DATA_DIR = vim.fn.stdpath('data') .. '/devdocs'
local STATE_FILE = DEVDOCS_DATA_DIR .. '/state.json'

local M = {}

local function initializeState()
  local statefileInfo = vim.uv.fs_stat(STATE_FILE)
  local stateFile
  if statefileInfo then
    stateFile = io.open(STATE_FILE, 'r+')
  else
    stateFile = io.open(STATE_FILE, 'w+')
  end
  if not stateFile then
    error('Error initializing Devdocs state', vim.log.levels.ERROR)
  end
  -- reading all at once should be fine since it should be a small file < 1MB
  local s = stateFile:read('*a')
  local state = {}

  if #s > 0 then
    state = vim.json.decode(s)
  end
  M.state = state
end

M.Update = function(self, key, val)
  self.state[key] = val
  local encoded = vim.json.encode(self.state)
  local stateFile = io.open(STATE_FILE, 'w+')
  if not stateFile then
    error('Error updating devdocs state', vim.log.levels.ERROR)
  end
  stateFile:write(encoded)
  stateFile:flush()
end

M.Reset = function(self)
  self.state = {}
  local encoded = vim.json.encode(self.state)
  local stateFile = io.open(STATE_FILE, 'w+')
  if not stateFile then
    error('Error updating devdocs state', vim.log.levels.ERROR)
  end
  stateFile:write(encoded)
  stateFile:flush()
end

M.Get = function(self, key)
  return self.state[key]
end

initializeState()

return M
