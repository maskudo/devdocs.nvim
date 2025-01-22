local M = {}
local uv = vim.uv

M.CreateDirIfNotExists = function(dir)
  local dirExists = uv.fs_stat(dir)
  if dirExists then
    return true
  end
  local res = uv.fs_mkdir(dir, 511) -- 511 is octal for 0777
  if not res then
    return false
  end
  return true
end

return M
