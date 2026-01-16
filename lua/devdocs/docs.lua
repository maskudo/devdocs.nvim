---@class Docs
local M = {}

local C = require('devdocs.constants')

--- @class Devdoc
--- @field db_size number Database size in bytes
--- @field links DevdocLink Table containing links related to the documentation
--- @field mtime number Last modified time (UNIX timestamp)
--- @field name string Name of the documentation/project
--- @field release string Version release
--- @field slug string Unique identifier slug
--- @field type string Type/category of the documentation
--- @field version string Version string (can be empty)

--- @class DevdocLink
--- @field code string? Optional GitHub/Code repository link
--- @field home string? Optional homepage link

--- @class DevdocStatus
--- @field downloaded boolean
--- @field extracted boolean

---@class Doc

---Creates a directory using a shell command native to the platform
---@param dir string Directory to create
M.Mkdir = function(dir)
  os.execute('mkdir -p ' .. dir)
end

-- Update for windows
if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 or os.getenv('OS') == 'Windows_NT' then
  M.Mkdir = function(dir)
    os.execute(
      "powershell.exe -NoLogo -NonInteractive -NoProfile -Command New-Item -ErrorAction SilentlyContinue -ItemType Directory -Force -Path '"
        .. dir
        .. "'"
    )
  end
end

---Initialize DevDocs directories
M.InitializeDirectories = function()
  M.Mkdir(C.DEVDOCS_DATA_DIR)
  M.Mkdir(C.DOCS_DIR)
  local dataDirExists = vim.fn.mkdir(C.DEVDOCS_DATA_DIR, 'p') == 1
  local docsDirExists = vim.fn.mkdir(C.DOCS_DIR, 'p') == 1
  assert(dataDirExists and docsDirExists, 'Error initializing DevDocs directories')
end

---

---Initialize devdocs for metadata.
---Downloads a list of all available docs
---@param opts { force: boolean } | nil
---@param callback function|nil Function called after fetching metadata
---@return nil
M.InitializeMetadata = function(opts, callback)
  if opts and opts.force then
    return M.FetchDevdocsMetadata(callback)
  end
  local metadata = require('devdocs.state'):Get('metadata')
  if metadata and metadata.downloaded then
    if callback ~= nil then
      return callback()
    end
  end
  M.FetchDevdocsMetadata(callback)
end

---Fetches and stores metadata in ${DEVDOCS_DATA_DIR}/metadata.json
---@param onComplete function|nil
M.FetchDevdocsMetadata = function(onComplete)
  vim.system({
    'curl',
    '-s',
    'https://devdocs.io/docs/docs.json',
    '-o',
    C.METADATA_FILE,
  }, { text = false }, function(res)
    if res.code == 0 then
      require('devdocs.state'):Update('metadata', {
        downloaded = true,
      })
      if onComplete ~= nil then
        onComplete()
      end
    else
      print('Error Downloading metadata')
    end
  end)
end

---Returns available dev docs
---@return Devdoc[]
M.GetDownloadableDocs = function()
  local file = io.open(C.METADATA_FILE, 'r')
  if not file then
    vim.notify('No available docs. Use DevDocsFetch to fetch them.')
    return {}
  end
  local text = file:read('*a')
  local availableDocs = vim.json.decode(text)
  return availableDocs
end

---Constructs download link for a doc(slug)
---@param doc doc
---@return string
M.ConstructDownloadLink = function(doc)
  return 'https://documents.devdocs.io/' .. doc .. '/db.json'
end

---Downloads json docs for any specified doc
---@param slug string Doc to be downloaded
---@param callback function Function called after download
M.DownloadDocs = function(slug, callback)
  local downloadLink = M.ConstructDownloadLink(slug)
  vim.system({
    'curl',
    '-sS',
    downloadLink,
  }, { text = false }, function(res)
    if res.code ~= 0 then
      vim.schedule(function()
        vim.notify('Error downloading doc for ' .. slug .. ': ' .. res.stderr)
      end)
      return
    end
    vim.system({
      'jq',
      '-c',
      'to_entries[]',
    }, { test = false, stdin = res.stdout }, function(ndjson)
      assert(ndjson.code == 0, 'Error processing json for ' .. slug)
      local f = io.open(C.DOCS_DIR .. '/' .. slug .. '.json', 'w')
      assert(f, 'Error creating file for ' .. slug)
      local _, err = f:write(ndjson.stdout)
      assert(not err, 'Error writing')
      f:close()
      require('devdocs.state'):Update(slug, {
        downloaded = true,
      })
      callback()
    end)
  end)
end

---Extracts json docs into markdown files
---@param slug string Doc to be extracted
---@param callback function? Function called after extraction
M.ExtractDocs = function(slug, callback)
  local filepath = C.DOCS_DIR .. '/' .. slug .. '.json'

  local activeJobs = 0
  local MAX_ACTIVE_JOBS = 5

  local getDocsData = coroutine.create(function()
    for line in io.lines(filepath) do
      local entry = vim.json.decode(
        line,
        { luanil = {
          object = true,
          array = true,
        } }
      )
      local title = entry.key
      local htmlContent = entry.value
      local parts = vim.split(title, '/', { trimempty = true, plain = true })
      local filename = table.remove(parts, #parts) .. '.md'
      local dir = C.DOCS_DIR
        .. '/'
        .. slug
        .. (#parts > 0 and '/' .. table.concat(parts, '/') or '')
      local outputFile = dir .. '/' .. filename

      M.Mkdir(dir)
      coroutine.yield({ outputFile = outputFile, htmlContent = htmlContent })
    end
  end)
  local function processDocs()
    if activeJobs <= MAX_ACTIVE_JOBS and coroutine.status(getDocsData) ~= 'dead' then
      local success, job = coroutine.resume(getDocsData)
      if success and job then
        activeJobs = activeJobs + 1
        M.ConvertHtmlToMarkdown(job.htmlContent, job.outputFile, function()
          activeJobs = activeJobs - 1
          vim.defer_fn(processDocs, 0)
        end)
      end
    elseif coroutine.status(getDocsData) == 'dead' then
      if activeJobs == 0 then
        require('devdocs.state'):Update(slug, {
          downloaded = true,
          extracted = true,
        })
        vim.schedule(function()
          vim.notify('Downloaded Docs for ' .. slug .. ' successfully')
        end)
        if callback ~= nil then
          callback()
        end
      end
    else
      vim.defer_fn(processDocs, 0)
    end
  end

  for _ = 1, MAX_ACTIVE_JOBS do
    processDocs()
  end
end

---Downloads json docs for any specified doc
---@param slug doc Doc to be downloaded
M.InstallDocs = function(slug)
  M.DownloadDocs(slug, function()
    M.ExtractDocs(slug)
  end)
end

local function clean_up_markdown_filter()
  local path = vim.fn.tempname() .. '.lua'
  local f = io.open(path, 'w')
  if not f then
    return nil
  end
  f:write([[
    function Div(el)
      return el.content
    end

    -- Drop empty paragraphs
    function Para(el)
      if #el.content == 0 then
        return {}
      end
      return el
    end

    function BlockQuote(el)
      return el
    end

    function Link(el)
      -- If link text equals URL, keep it simple
      if #el.content == 1 and el.content[1].text == el.target then
        return el.target
      end
      return el
    end

    function Span(el)
      return el.content
    end

    function Strong(el)
      return pandoc.Strong(el.content)
    end

    function Emph(el)
      return pandoc.Emph(el.content)
    end

    function Code(el)
      return el
    end


    function Header(el)
      if #el.content == 0 then
        return {}
      end
      return el
    end

    function HorizontalRule(el)
      return pandoc.HorizontalRule()
    end


    function BulletList(el)
      return el
    end

    function OrderedList(el)
      return el
    end

  ]])
  f:close()
  return path
end

local temp_filter = clean_up_markdown_filter()

---Converts html documents to a bunch of markdown files
---@param htmlContent string
---@param outputFile string File the output markdown is stored on
---@param callback function Function called after conversion
M.ConvertHtmlToMarkdown = function(htmlContent, outputFile, callback)
  vim.system({
    'pandoc',
    '-f',
    'html',
    '-t',
    'gfm',
    temp_filter and '--lua-filter=' .. temp_filter or '',
    '-o',
    outputFile,
  }, { stdin = htmlContent }, function(res)
    callback()
    assert(res.code == 0, 'Error converting to markdown:', res.stderr)
  end)
end

---Get downloaded/extracted status of docs
---@param slug string The doc
---@return DevdocStatus {downloaded: string, extracted: string}
M.GetDocStatus = function(slug)
  local status = require('devdocs.state'):Get(slug)
  return status
end

---Get all available docs
--- @alias doc string
---@return {doc: boolean}
M.GetAvailableDocs = function()
  local availableDocs = M.GetDownloadableDocs()
  local set = {}
  for _, doc in ipairs(availableDocs) do
    set[doc.slug] = true
  end
  return set
end

---Get all installed docs
---@return {doc:doc}
M.GetInstalledDocs = function()
  local state = require('devdocs.state').state
  local installed = {}
  for doc, status in pairs(state) do
    if doc ~= 'metadata' and status.extracted then
      table.insert(installed, doc)
    end
  end
  return installed
end

---Check if doc is available for download
---@param doc string
---@return boolean
M.ValidateDocAvailability = function(doc)
  local availableDocs = M.GetAvailableDocs()
  return availableDocs[doc] or false
end

---Separated provided docs into valid and invalid docs
---@param docs doc[]
---@return table {validDocs: string[], invalidDocs: string[]}
M.ValidateDocsAvailability = function(docs)
  local availableDocs = M.GetAvailableDocs()
  local invalidDocs = {}
  local validDocs = {}
  for _, doc in ipairs(docs) do
    if availableDocs[doc] == true then
      table.insert(validDocs, doc)
    else
      table.insert(invalidDocs, doc)
    end
  end
  return { validDocs = validDocs, invalidDocs = invalidDocs }
end

M.DeleteDoc = function(doc)
  local docFile = C.DOCS_DIR .. '/' .. doc .. '.json'
  local docDir = C.DOCS_DIR .. '/' .. doc

  local deleteExtracted = vim.fn.delete(docDir, 'rf')
  local deleteDownloaded = vim.fn.delete(docFile)

  assert(deleteExtracted == 0, 'Error deleting extracted files for ' .. doc)
  assert(deleteDownloaded == 0, 'Error deleting downloaded files for ' .. doc)

  require('devdocs.state'):Update(doc, {
    downloaded = false,
    extracted = false,
  })
end

---Returns doc filepaths
---@param doc doc
---@return string[] | nil
M.GetDocFiles = function(doc)
  if not doc then
    return nil
  end
  local files = vim.fs.find(function()
    return true
  end, { limit = math.huge, type = 'file', path = C.DOCS_DIR .. '/' .. doc })
  return files
end

return M
