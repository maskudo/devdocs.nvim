local M = {}
local DEVDOCS_DATA_DIR = vim.fn.stdpath('data') .. '/devdocs'
local METADATA_FILE = DEVDOCS_DATA_DIR .. '/metadata.json'
local DOCS_DIR = DEVDOCS_DATA_DIR .. '/docs'
local helper = require('devdocs.helpers')

M.InitializeDirectories = function()
  local dataDirExists = helper.CreateDirIfNotExists(DEVDOCS_DATA_DIR)
  local docsDirExists = helper.CreateDirIfNotExists(DOCS_DIR)
  assert(dataDirExists and docsDirExists, 'Error initializing DevDocs directories')
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
    vim.notify('No available docs. Use DevDocsFetch to fetch them.')
    return {}
  end
  local text = file:read('*a')
  local availableDocs = vim.json.decode(text)
  return availableDocs
end

M.PickDocs = function()
  local docs = M.ShowAvailableDocs()
  local names = {}
  for _, doc in ipairs(docs) do
    table.insert(names, doc.slug)
  end
  vim.ui.select(names, { prompt = 'Select docs to install' }, function(choice)
    print(choice)
  end)
end

end

return M
