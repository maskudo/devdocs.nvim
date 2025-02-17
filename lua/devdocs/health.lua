local M = {}
local function checkhealth(command)
  if vim.fn.executable(command) == 0 then
    vim.health.error(command .. ' not found')
  else
    vim.health.ok(command .. ' found')
  end
end
M.check = function()
  vim.health.start('Devdocs tools check')
  checkhealth('curl')
  checkhealth('pandoc')
end

return M
