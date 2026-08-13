-- nvim-cmp source for Pi autocomplete
-- Sends completion requests to Pi agent via RPC

local M = {}

-- Config reference (set by init.lua)
M.config = {
  enabled = true,
  filetypes = {},
  trigger_length = 2,
}

-- Set config from plugin config
function M.set_config(config)
  M.config = vim.tbl_deep_extend("force", M.config, config or {})
end

-- Check if source is enabled for current filetype
local function is_enabled_for_filetype()
  if not M.config.enabled then
    return false
  end
  if not M.config.filetypes or #M.config.filetypes == 0 then
    return true -- enabled for all filetypes
  end
  local ft = vim.bo.filetype
  for _, f in ipairs(M.config.filetypes) do
    if f == ft then
      return true
    end
  end
  return false
end

-- Get the prefix (text before cursor) for completion
local function get_completion_prefix(params)
  -- params.context.cursor gives cursor position
  -- params.context.cursor_before_line gives text before cursor on current line
  local before_line = params.context.cursor_before_line or ""
  -- Find the last word/identifier before cursor
  local prefix = before_line:match("([%w_%.]+)$") or ""
  return prefix
end

-- Get trigger character that initiated completion
local function get_trigger_char(params)
  -- nvim-cmp provides trigger character in params.completion_context
  if params.completion_context and params.completion_context.triggerCharacter then
    return params.completion_context.triggerCharacter
  end
  return "."
end

-- Create a new source instance
function M.new()
  local source = {}

  -- Required by nvim-cmp: get trigger characters
  source.get_trigger_characters = function()
    return { ".", ":", "(", "[", "@" }
  end

  -- Required by nvim-cmp: complete function
  source.complete = function(self, params, callback)
    -- Check if enabled for this filetype
    if not is_enabled_for_filetype() then
      callback({})
      return
    end

    -- Check trigger length
    local prefix = get_completion_prefix(params)
    if #prefix < M.config.trigger_length then
      callback({})
      return
    end

    -- Get context from context module
    local context = require("pi_neovim.context")
    local ctx = context.get_for_completion()

    -- Build request payload
    local trigger_char = get_trigger_char(params)
    local request_data = {
      type = "complete",
      context = ctx,
      trigger = trigger_char,
      prefix = prefix,
      -- Include cursor position for Pi
      cursor = ctx.buffer.cursor,
    }

    -- Send request via process module
    local process = require("pi_neovim.process")

    local request_id = process.send_request(request_data, function(response, error)
      if error then
        vim.notify("Pi completion error: " .. error, vim.log.levels.WARN)
        callback({})
        return
      end

      if not response or not response.completions then
        callback({})
        return
      end

      -- Transform Pi completions to nvim-cmp format
      local items = {}
      for _, comp in ipairs(response.completions) do
        local item = {
          label = comp.label or comp.text or "",
          kind = comp.kind or 1, -- Text = 1, Method = 2, Function = 3, etc.
          detail = comp.detail or "",
          documentation = comp.documentation or comp.description or "",
          insertText = comp.insertText or comp.label or comp.text or "",
          insertTextFormat = comp.insertTextFormat or 1, -- PlainText = 1, Snippet = 2
        }
        table.insert(items, item)
      end

      callback(items)
    end, 10000) -- 10 second timeout for completions

    if not request_id then
      callback({})
    end
  end

  -- Optional: resolve completion items (for documentation, etc.)
  source.resolve = function(self, completion_item, callback)
    callback(completion_item)
  end

  return source
end

-- For backward compatibility, also expose as module functions
M.get_trigger_characters = function()
  return { ".", ":", "(", "[", "@" }
end

M.complete = function(self, params, callback)
  -- This is used when source is registered without .new()
  -- Create a temporary source instance
  local source = M.new()
  source:complete(params, callback)
end

return M