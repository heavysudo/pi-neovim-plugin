-- nvim-cmp source for Pi autocomplete
-- TODO: Implement nvim-cmp source

local M = {}

-- Create a new source instance
function M.new()
  local source = {}

  -- Required by nvim-cmp: get trigger characters
  source.get_trigger_characters = function()
    return { "." }
  end

  -- Required by nvim-cmp: complete function
  source.complete = function(self, params, callback)
    -- TODO: Implement completion request
    callback({})
  end

  -- Optional: resolve completion items
  source.resolve = function(self, completion_item, callback)
    callback(completion_item)
  end

  return source
end

-- For backward compatibility, also expose as module functions
M.get_trigger_characters = function()
  return { "." }
end

M.complete = function(self, params, callback)
  callback({})
end

return M