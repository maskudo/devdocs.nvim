local M = {}
local uv = vim.uv
local DEVDOCS_DATA_DIR = vim.fn.stdpath('data') .. '/devdocs/'
local METADATA_FILE = DEVDOCS_DATA_DIR .. 'metadata.json'

vim.notify(DEVDOCS_DATA_DIR .. METADATA_FILE)
local function ensureDatadirExists()
  local stat = uv.fs_stat(DEVDOCS_DATA_DIR)
  if not stat then
    local res = uv.fs_mkdir(DEVDOCS_DATA_DIR, 511) -- 511 is octal for 0777
    print('create dir: ' .. res and DEVDOCS_DATA_DIR)
  end
end

M.FetchDevdocsMetadata = function()
  ensureDatadirExists()

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
