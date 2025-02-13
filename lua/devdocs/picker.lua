local M = {}
local C = require('devdocs.constants')
local D = require('devdocs.docs')
local Snacks = require('snacks')
local H = require('devdocs.helpers')

---Show list of all available docs for a DevDoc
---@param doc doc
---@param callback function?
M.ViewDoc = function(doc, callback)
  Snacks.picker.smart({
    cwd = C.DOCS_DIR .. '/' .. doc,
    exclude = { '*.json' },
    format = 'text',
    title = 'Select doc',
    transform = function(item)
      item.text = item.text:gsub('/index', '')
      item.text = item.text:gsub('/', ' ')
      item.text = item.text:gsub('.md', '')
      item.text = H.toTitleCase(item.text)
      return item
    end,
    filter = { cwd = true },
    sort = { fields = { 'text' } },
    confirm = function(picker)
      local file = picker:current()._path
      picker:close()
      if callback == nil then
        Snacks.win.new({ file = file, position = 'right' }):add_padding()
      else
        callback({ file = file })
      end
    end,
  })
end

M.ViewDocs = function()
  local docs = D.GetInstalledDocs()
  ---@diagnostic disable-next-line: redundant-parameter -- documentation error
  Snacks.picker.select(docs, { prompt = 'Select Doc' }, function(selected)
    M.ViewDoc(selected)
  end)
end

M.ShowAvailableDocs = function()
  local docs = D.GetDownloadableDocs()
  local items = {}
  for _, doc in ipairs(docs) do
    table.insert(items, doc.slug)
  end
  ---@diagnostic disable-next-line: redundant-parameter -- documentation error
  Snacks.picker.select(items, { prompt = 'Select Doc to Download' }, function(selected)
    D.InstallDocs(selected)
  end)
end

return M
