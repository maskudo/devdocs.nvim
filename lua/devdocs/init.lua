---@class DevDocs
local M = {}

---@private
---@class Docs
local D = require('devdocs.docs')

local P = require('devdocs.picker')

---Download docs from ensure installed docs list
---@private
---@param ensureInstalled {doc: doc}
local function downloadDocs(ensureInstalled)
  local validatedDocs = D.ValidateDocsAvailability(ensureInstalled)
  local toInstall = validatedDocs.validDocs
  if #validatedDocs.invalidDocs > 0 then
    vim.notify(
      '[[DEVDOCS.NVIM]] Following docs are not available and will not be installed: \n'
        .. vim.fn.join(validatedDocs.invalidDocs, '\n')
        .. '\nPlease remove them from opts',
      vim.log.levels.WARN
    )
  end
  if #toInstall == 0 then
    return
  end
  local downloadList = {}
  local extractList = {}
  for _, doc in ipairs(toInstall) do
    local status = D.GetDocStatus(doc)
    if not status or not status.downloaded then
      table.insert(downloadList, doc)
    elseif status.downloaded and not status.extracted then
      table.insert(extractList, doc)
    end
  end
  if #downloadList == 0 and #extractList == 0 then
    return
  end

  local extractJob
  extractJob = coroutine.create(function(toExtract)
    for i, doc in ipairs(toExtract) do
      print('Extracting DevDocs for ' .. doc)
      D.ExtractDocs(doc, function()
        if coroutine.status(extractJob) ~= 'dead' then
          vim.defer_fn(function()
            coroutine.resume(extractJob, toExtract)
          end, 0)
        end
      end)
      if i == #toExtract then
        return
      end
      coroutine.yield()
    end
  end)

  local downloadJob
  downloadJob = coroutine.create(function()
    for i, doc in ipairs(downloadList) do
      print('Downloading DevDocs for ' .. doc)
      D.DownloadDocs(doc, function()
        table.insert(extractList, doc)
        vim.defer_fn(function()
          if coroutine.status(downloadJob) ~= 'dead' then
            coroutine.resume(downloadJob)
          end
        end, 0)
        -- start extracting after last download finishes
        if i == #downloadList then
          if coroutine.status(extractJob) ~= 'dead' then
            vim.defer_fn(function()
              coroutine.resume(extractJob, extractList)
            end, 0)
          end
          return
        end
      end)
      coroutine.yield()
    end
  end)

  if coroutine.status(downloadJob) ~= 'dead' then
    coroutine.resume(downloadJob)
  end
  -- extract if nothing to download
  if #downloadList == 0 and #extractList > 0 and coroutine.status(extractJob) ~= 'dead' then
    coroutine.resume(extractJob, extractList)
  end
end

---Setup User Commands
---@private
local function setupCommands()
  vim.api.nvim_create_user_command('DevDocs', function(opts)
    local subcmd = opts.fargs[1]
    if not subcmd then
      vim.notify('[[DevDocs.nvim]] Available cmd: fetch, install, get', vim.log.levels.INFO)
    end
    if subcmd == 'fetch' then
      D.InitializeMetadata({ force = true })
    elseif subcmd == 'install' then
      local doc = opts.fargs[2]
      if doc ~= nil then
        D.InstallDocs(doc)
      else
        P.ShowAllDocs()
      end
    elseif subcmd == 'get' then
      local doc = opts.fargs[2]
      if not doc then
        P.ViewDocs()
      else
        P.ViewDoc(doc)
      end
    end
  end, { nargs = '*' })
end

M.setup = function(opts)
  D.InitializeDirectories()
  D.InitializeMetadata({}, function()
    local ensureInstalled = opts.ensure_installed or {}
    downloadDocs(ensureInstalled)
  end)
  setupCommands()
end

---Get all downloadable devdocs
---@return {doc:Devdoc}
M.GetAllDocs = D.GetDownloadableDocs

---Get all installed docs
---@return {doc: doc}
M.GetInstalledDocs = D.GetInstalledDocs

--- Get filepaths of all documents for a doc
--- @param doc doc
--- @return [string] | nil
M.GetDoc = function(doc)
  return D.GetDocFiles(doc)
end

--- Install Doc
--- @async
--- @param doc doc
M.InstallDoc = function(doc)
  return D.InstallDocs(doc)
end

---Get download link for a doc(slug)
---@param slug doc
---@return string
M.GetDownloadLinkForDoc = function(slug)
  return D.ConstructDownloadLink(slug)
end

---Fetch devdoc metadata
---@async
---@param callback function | nil
M.FetchDevdocs = function(callback)
  D.InitializeMetadata({ force = true }, callback)
end

return M
