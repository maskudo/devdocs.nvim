local M = {}
local C = require('devdocs.constants')

---Initialize DevDocs directories
M.InitializeDirectories = function()
  os.execute('mkdir -p ' .. C.DEVDOCS_DATA_DIR)
  os.execute('mkdir -p ' .. C.DOCS_DIR)
  local dataDirExists = vim.fn.mkdir(C.DEVDOCS_DATA_DIR, 'p')
  local docsDirExists = vim.fn.mkdir(C.DOCS_DIR, 'p')
  assert(dataDirExists and docsDirExists, 'Error initializing DevDocs directories')
end

M.InitializeMetadata = function(opts)
  if opts and opts.force then
    return M.FetchDevdocsMetadata()
  end
  local metadata = require('devdocs.state'):Get('metadata')
  if metadata and metadata.downloaded then
    return
  end
  M.FetchDevdocsMetadata()
end

---Fetches and stores metadata in ${DEVDOCS_DATA_DIR}/metadata.json
M.FetchDevdocsMetadata = function()
  vim.system({
    'curl',
    '-s',
    'https://documents.devdocs.io/docs.json',
    '-o',
    C.METADATA_FILE,
  }, { text = false }, function(res)
    if res.code == 0 then
      require('devdocs.state'):Update('metadata', {
        downloaded = true,
      })
    else
      print('Error Downloading metadata')
    end
  end)
end

---Returns available dev docs
---@return table
M.GetAvailableDocs = function()
  local file = io.open(C.METADATA_FILE, 'r')
  if not file then
    vim.notify('No available docs. Use DevDocsFetch to fetch them.')
    return {}
  end
  local text = file:read('*a')
  local availableDocs = vim.json.decode(text)
  return availableDocs
end

M.PickDocs = function()
  local docs = M.GetAvailableDocs()
  local names = {}
  for _, doc in ipairs(docs) do
    table.insert(names, doc.slug)
  end
  vim.ui.select(names, { prompt = 'Select docs to install' }, function(choice)
    print(choice)
  end)
end

M.DownloadDocs = function(slug, onDownload)
  local downloadLink = 'https://documents.devdocs.io/' .. slug .. '/db.json'
  vim.system({
    'curl',
    '-s',
    downloadLink,
  }, { text = false }, function(res)
    assert(res.code == 0, 'Error downloading docs')
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
      onDownload()
    end)
  end)
end

M.ShowState = function()
  print(vim.inspect(require('devdocs.state').state))
end

M.ExtractDocs = function(slug, onComplete)
  local filepath = C.DOCS_DIR .. '/' .. slug .. '.json'

  local activeJobs = 0
  local MAX_ACTIVE_JOBS = 20

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
      local dir = C.DOCS_DIR .. '/' .. slug .. '/' .. table.concat(parts, '/')
      local outputFile = dir .. '/' .. filename

      os.execute('mkdir -p ' .. dir)
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
        onComplete()
      end
    else
      vim.defer_fn(processDocs, 0)
    end
  end

  for _ = 1, MAX_ACTIVE_JOBS do
    processDocs()
  end
end

M.ConvertHtmlToMarkdown = function(htmlContent, outputFile, callback)
  vim.system({
    'pandoc',
    '-f',
    'html',
    '-t',
    'markdown',
    '-o',
    outputFile,
  }, { stdin = htmlContent }, function(res)
    callback()
    assert(res.code == 0, 'Error converting to markdown:', res.stderr)
  end)
end

M.DownloadAndExtractDocs = function(slug)
  M.DownloadDocs(slug, function()
    M.ExtractDocs(slug)
  end)
end

M.GetDocStatus = function(slug)
  local status = require('devdocs.state'):Get(slug)
  return status
end

M.GetDocsSet = function()
  local availableDocs = M.GetAvailableDocs()
  local set = {}
  for _, doc in ipairs(availableDocs) do
    set[doc.slug] = true
  end
  return set
end

M.ValidateDocAvailability = function(doc)
  local availableDocs = M.GetDocsSet()
  return availableDocs[doc] or false
end

M.ValidateDocsAvailability = function(docs)
  local availableDocs = M.GetDocsSet()
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

return M
