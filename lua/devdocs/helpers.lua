local M = {}
--- Converts a string to title case (first letter capitalized, rest lowercase)
--- @param str string The input string
--- @return string The title-cased string
M.toTitleCase = function(str)
  ---@diagnostic disable-next-line: redundant-return-value
  return str:gsub('(%S)(%S*)', function(first, rest)
    return (first:upper() .. rest:lower())
  end)
end

return M
