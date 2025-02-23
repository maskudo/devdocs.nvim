local M = {}
local C = require('devdocs.constants')
---@class Docs
local D = require('devdocs.docs')
local H = require('devdocs.helpers')

---Show list of all available docs for a DevDoc
---@param doc doc
---@param callback function?
M.ViewDoc = function(doc, callback)
  local files = D.GetDocFiles(doc)
  if not files then
    vim.notify("Doc doesn't have associated documents", vim.log.levels.WARN)
    return
  end
  local prettifiedFilenames = {}
  for i, file in ipairs(files) do
    local name = file
    name = name:gsub(C.DOCS_DIR .. '/' .. doc, '')
    name = name:gsub('/index', '')
    name = name:gsub('/', ' ')
    name = name:gsub('.md', '')
    name = H.toTitleCase(name)
    name = vim.fn.trim(name)
    if #name == 0 then
      name = 'Index'
    end
    prettifiedFilenames[i] = name
  end
  vim.ui.select(
    prettifiedFilenames,
    { prompt = ('Select Doc' .. '( ' .. doc .. ' )') },
    function(_, index)
      if not index then
        return
      end
      local file = files[index]
      vim.cmd('split ' .. file .. ' | setlocal readonly')
      vim.diagnostic.enable(false, { bufnr = 0 })
    end
  )
end

M.ViewDocs = function()
  local docs = D.GetInstalledDocs()
  ---@diagnostic disable-next-line: redundant-parameter -- documentation error
  vim.ui.select(docs, { prompt = 'Select Doc' }, function(selected)
    if not selected then
      return
    end
    M.ViewDoc(selected)
  end)
end

M.ShowAllDocs = function()
  local docs = D.GetDownloadableDocs()
  local items = {}
  for _, doc in ipairs(docs) do
    table.insert(items, doc.slug)
  end
  ---@diagnostic disable-next-line: redundant-parameter -- documentation error
  vim.ui.select(items, { prompt = 'Select Doc to Download' }, function(selected)
    if not selected then
      return
    end
    vim.notify('Downloading docs for ' .. selected, vim.log.levels.INFO)
    D.InstallDocs(selected)
  end)
end

return M
