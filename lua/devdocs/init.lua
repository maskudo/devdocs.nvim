local M = {}
local D = require('devdocs.docs')

M.setup = function(opts)
  D.InitializeDirectories()
  D.InitializeMetadata()
  local ensureInstalled = opts.ensure_installed or {}
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
  if not toInstall then
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
      D.ExtractDocs(doc, function()
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
      D.DownloadDocs(doc, function()
        table.insert(extractList, doc)
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

return M
