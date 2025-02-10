local M = {}
local C = require('devdocs.constants')
local D = require('devdocs.docs')
local S = require('snacks')

M.PickDoc = function(doc)
  S.picker.smart({
    cwd = C.DOCS_DIR .. '/' .. doc,
    exclude = { '*.json' },
    filter = { cwd = true },
    formatters = { file = { filename_first = false } },
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
  local docs = D.GetAvailableDocs()
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
