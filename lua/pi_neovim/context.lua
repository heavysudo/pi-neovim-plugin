-- Context gathering for Pi Neovim plugin
-- TODO: Implement context gathering as per context_schema.md

local M = {}

-- Gather context for autocomplete
function M.get_for_completion()
  return {}
end

-- Gather context for general prompt
function M.get_for_prompt()
  return {}
end

return M