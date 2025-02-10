local M = {}
M.DEVDOCS_DATA_DIR = vim.fn.stdpath('data') .. '/devdocs'
M.METADATA_FILE = M.DEVDOCS_DATA_DIR .. '/metadata.json'
M.DOCS_DIR = M.DEVDOCS_DATA_DIR .. '/docs'

return M
