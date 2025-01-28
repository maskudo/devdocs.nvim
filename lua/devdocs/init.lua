local M = {}
local DEVDOCS_DATA_DIR = vim.fn.stdpath('data') .. '/devdocs'
local METADATA_FILE = DEVDOCS_DATA_DIR .. '/metadata.json'
local DOCS_DIR = DEVDOCS_DATA_DIR .. '/docs'
local helper = require('devdocs.helpers')

---Initialize DevDocs directories
M.InitializeDirectories = function()
  local dataDirExists = helper.CreateDirIfNotExists(DEVDOCS_DATA_DIR)
  local docsDirExists = helper.CreateDirIfNotExists(DOCS_DIR)
  assert(dataDirExists and docsDirExists, 'Error initializing DevDocs directories')
end

---Fetches and stores metadata in ${DEVDOCS_DATA_DIR}/metadata.json
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

---Returns available dev docs
---@return table
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

M.DownloadDocs = function(slug)
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
      assert(ndjson.code == 0, 'Error processing json')
      local f = io.open(DOCS_DIR .. '/' .. slug .. '.json', 'w')
      assert(f, 'Error creating file for ' .. slug)
      local _, err = f:write(ndjson.stdout)
      assert(not err, 'Error writing')
      f:close()
      vim.notify('Downloaded docs for ' .. slug .. ' successfully', vim.log.levels.INFO)
    end)
  end)
end

M.ExtractDocs = function(slug)
  local filepath = DOCS_DIR .. '/' .. slug .. '.json'

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
      local dir = DOCS_DIR .. '/' .. slug .. '/' .. table.concat(parts, '/')
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
        print('Documents for ' .. slug .. ' extracted successfully')
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

return M
