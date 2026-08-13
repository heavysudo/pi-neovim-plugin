-- Streaming response handler for Pi Neovim plugin
-- Accumulates streaming chunks, handles incremental UI updates, partial JSON

local M = {}

-- Response buffer state
local response_buffers = {}

-- Create a new response buffer for a request
function M.create(request_id)
  response_buffers[request_id] = {
    chunks = {},
    full_text = "",
    is_complete = false,
    callback = nil,
    on_chunk = nil,
  }
  return response_buffers[request_id]
end

-- Get response buffer
function M.get(request_id)
  return response_buffers[request_id]
end

-- Delete response buffer
function M.delete(request_id)
  response_buffers[request_id] = nil
end

-- Add a chunk to the response buffer
-- Handles both plain text streaming and JSONL chunks
function M.add_chunk(request_id, chunk)
  local buf = response_buffers[request_id]
  if not buf then
    return false, "no buffer for request_id: " .. request_id
  end

  table.insert(buf.chunks, chunk)
  buf.full_text = buf.full_text .. chunk

  -- Call chunk callback if set
  if buf.on_chunk then
    buf.on_chunk(chunk, buf.full_text)
  end

  return true
end

-- Try to parse accumulated text as JSON
-- Returns parsed object if complete, nil if incomplete
function M.try_parse_json(request_id)
  local buf = response_buffers[request_id]
  if not buf then
    return nil, "no buffer"
  end

  local ok, parsed = pcall(vim.json.decode, buf.full_text)
  if ok then
    buf.is_complete = true
    return parsed
  end

  -- Check if it looks like incomplete JSON
  -- (starts with { but doesn't end with })
  local trimmed = buf.full_text:match("^%s*(.*)%s*$")
  if trimmed:sub(1, 1) == "{" and trimmed:sub(-1) ~= "}" then
    return nil, "incomplete"
  end

  return nil, "invalid"
end

-- Set completion callback
function M.on_complete(request_id, callback)
  local buf = response_buffers[request_id]
  if buf then
    buf.callback = callback
  end
end

-- Set chunk callback (for streaming UI updates)
function M.on_chunk(request_id, callback)
  local buf = response_buffers[request_id]
  if buf then
    buf.on_chunk = callback
  end
end

-- Finalize response - call completion callback
function M.finalize(request_id)
  local buf = response_buffers[request_id]
  if not buf then
    return
  end

  buf.is_complete = true

  -- Try to parse as JSON
  local parsed, err = M.try_parse_json(request_id)
  if parsed then
    if buf.callback then
      buf.callback(parsed, nil)
    end
  else
    -- Return as plain text
    if buf.callback then
      buf.callback({ text = buf.full_text }, nil)
    end
  end

  -- Clean up
  response_buffers[request_id] = nil
end

-- Handle a complete JSONL line (for non-streaming responses)
function M.handle_jsonl_line(request_id, line)
  local ok, parsed = pcall(vim.json.decode, line)
  if ok then
    local buf = response_buffers[request_id]
    if buf and buf.callback then
      buf.callback(parsed, nil)
    end
    return parsed
  end
  return nil
end

-- Check if response is complete
function M.is_complete(request_id)
  local buf = response_buffers[request_id]
  return buf and buf.is_complete
end

-- Get full accumulated text
function M.get_text(request_id)
  local buf = response_buffers[request_id]
  return buf and buf.full_text or ""
end

-- Clear all buffers (on disconnect)
function M.clear_all()
  response_buffers = {}
end

return M