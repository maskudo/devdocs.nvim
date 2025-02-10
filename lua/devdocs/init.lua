local M = {}
local D = require('devdocs.docs')
local P = require('devdocs.picker')

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
  extractJob = coroutine.create(function()
    for i, doc in ipairs(extractList) do
      print('Extracting DevDocs for ' .. doc)
      D.ExtractDocs(doc, function()
        print('Docs for ' .. doc .. ' extracted successfully')
        if coroutine.status(extractJob) ~= 'dead' then
          vim.defer_fn(function()
            coroutine.resume(extractJob)
          end, 0)
        end
      end)
      if i == #extractList then
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
        print('Docs for ' .. doc .. ' downloaded successfully')
        if coroutine.status(downloadJob) ~= 'dead' then
          vim.defer_fn(function()
            coroutine.resume(downloadJob)
          end, 0)
        end
      end)
      if i == #downloadList then
        if coroutine.status(extractJob) ~= 'dead' then
          vim.defer_fn(function()
            coroutine.resume(extractJob)
          end, 0)
        end
        return
      end
      coroutine.yield()
    end
  end)

  if coroutine.status(downloadJob) ~= 'dead' then
    coroutine.resume(downloadJob)
  end
  -- extract if nothing to download
  if #downloadList == 0 and #extractList > 0 and coroutine.status(extractJob) ~= 'dead' then
    coroutine.resume(extractJob)
  end
end

M.setup = function(opt)
  D.InitializeDirectories()
  D.InitializeMetadata()
  local ensureInstalled = opt.ensure_installed or {}
  downloadDocs(ensureInstalled)
  vim.api.nvim_create_user_command('DevDocs', function(opts)
    local subcmd = opts.fargs[1]
    if not subcmd then
      vim.notify('[[DevDocs.nvim]] Available cmd: fetch, install, get', vim.log.levels.INFO)
    end
    if subcmd == 'fetch' then
      D.InitializeMetadata({ force = true })
    elseif subcmd == 'install' then
      local doc = opts.fargs[2]
      if not D.ValidateDocAvailability(doc) then
        return vim.notify('Docs for ' .. doc .. " doesn't exist", vim.log.levels.ERROR)
      end
      D.DownloadDocs(doc)
    elseif subcmd == 'get' then
      local doc = opts.fargs[2]
      if not doc then
        P.PickDocs()
      else
        P.PickDoc(doc)
      end
    end
  end, { nargs = '*' })
end

return M
