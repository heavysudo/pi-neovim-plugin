-- nvim-cmp source for Pi autocomplete
-- TODO: Implement nvim-cmp source

local M = {}

-- Required by nvim-cmp
M.get_trigger_characters = function()
  return { "." } -- example
end

M.complete = function(self, params, callback)
  -- TODO: Implement completion request
  callback({})
end

return M