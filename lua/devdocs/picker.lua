local M = {}
local C = require('devdocs.constants')
local D = require('devdocs.docs')
local S = require('snacks')
local H = require('devdocs.helpers')

---Show list of all available docs for a DevDoc
---@param doc doc
---@param callback function?
M.PickDoc = function(doc, callback)
  S.picker.smart({
    cwd = C.DOCS_DIR .. '/' .. doc,
    exclude = { '*.json' },
    format = 'text',
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

local gen_items = function(docs)
  local items = {}
  for _, doc in ipairs(docs) do
    table.insert(items, { text = doc.slug, preview = { text = vim.inspect(doc) } })
  end
  return items
end

M.PickDocs = function()
  local docs = D.GetDownloadableDocs()
  local items = gen_items(docs)
  S.picker.pick({
    source = 'devdocs',
    items = items,
    preview = 'preview',
    format = 'text',
    confirm = function(picker, item)
      picker:close()
      M.PickDoc(item.text)
    end,
  })
end

return M
