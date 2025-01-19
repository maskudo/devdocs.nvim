local M = {}
local uv = vim.uv
local DEVDOCS_DATA_DIR = vim.fn.stdpath('data') .. '/devdocs'
local METADATA_FILE = DEVDOCS_DATA_DIR .. '/metadata.json'
local DOCS_DIR = DEVDOCS_DATA_DIR .. '/docs'

vim.notify(DEVDOCS_DATA_DIR .. METADATA_FILE)
M.InitializeDirectories = function()
  local dataDirExists = uv.fs_stat(DEVDOCS_DATA_DIR)
  local docsDirExists = uv.fs_stat(DOCS_DIR)
  if not dataDirExists then
    local res = uv.fs_mkdir(DEVDOCS_DATA_DIR, 511) -- 511 is octal for 0777
    if not res then
      vim.notify('Error creating data directory', vim.log.levels.ERROR)
    end
  end
  if not docsDirExists then
    local res = uv.fs_mkdir(DOCS_DIR, 511) -- 511 is octal for 0777
    if not res then
      vim.notify('Error creating data directory', vim.log.levels.ERROR)
    end
  end
end

M.FetchDevdocsMetadata = function()
  vim.system({
    'curl',
    '-s',
    'https://documents.devdocs.io/docs.json',
    '-o',
    METADATA_FILE,
  }, { text = false }, function(res)
    if res.code == 0 then
      print('Downloaded metadata')
    else
      print('Error Downloading metadata')
    end
  end)
end

M.ShowAvailableDocs = function()
  local file = io.open(METADATA_FILE, 'r')
  if not file then
    return vim.notify('No available docs. Use DevDocsFetch to fetch them.')
  end
  local text = file:read('*a')
  local availableDocs =
    vim.json.decode(text, { luanil = {
      array = true,
      object = true,
    } })
  vim.notify(vim.inspect(availableDocs[1]))
end

return M
