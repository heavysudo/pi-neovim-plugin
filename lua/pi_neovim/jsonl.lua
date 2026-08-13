-- JSONL (JSON Lines) parser for Pi RPC protocol
-- Handles streaming JSONL output from Pi agent process

local M = {}

-- Parser state
local parser_state = {
  buffer = "",
  on_event = nil,
  on_error = nil,
}

-- Reset parser state
function M.reset()
  parser_state.buffer = ""
end

-- Set event callback
-- callback(event) where event is a parsed JSON object
function M.set_on_event(callback)
  parser_state.on_event = callback
end

-- Set error callback
-- callback(error_message, raw_line)
function M.set_on_error(callback)
  parser_state.on_error = callback
end

-- Process incoming data chunk (may contain partial lines)
function M.process_chunk(chunk)
  if not chunk or chunk == "" then
    return
  end

  parser_state.buffer = parser_state.buffer .. chunk

  -- Split by newline, but keep the last partial line in buffer
  local lines = {}
  local start = 1
  while true do
    local nl = parser_state.buffer:find("\n", start, true)
    if not nl then
      break
    end
    local line = parser_state.buffer:sub(start, nl - 1)
    table.insert(lines, line)
    start = nl + 1
  end

  -- Remaining partial line stays in buffer
  parser_state.buffer = parser_state.buffer:sub(start)

  -- Process each complete line
  for _, line in ipairs(lines) do
    M._parse_line(line)
  end
end

-- Parse a single JSONL line
function M._parse_line(line)
  if line == "" then
    return
  end

  local ok, event = pcall(vim.json.decode, line)
  if not ok then
    if parser_state.on_error then
      parser_state.on_error("JSON parse error: " .. tostring(event), line)
    end
    return
  end

  if parser_state.on_event then
    parser_state.on_event(event)
  end
end

-- Get any remaining unparsed buffer (for debugging)
function M.get_buffer()
  return parser_state.buffer
end

-- Convenience: create a new parser instance with callbacks
function M.new(opts)
  opts = opts or {}
  local instance = {
    buffer = "",
    on_event = opts.on_event,
    on_error = opts.on_error,
  }

  function instance:process_chunk(chunk)
    if not chunk or chunk == "" then
      return
    end
    self.buffer = self.buffer .. chunk

    local lines = {}
    local start = 1
    while true do
      local nl = self.buffer:find("\n", start, true)
      if not nl then
        break
      end
      local line = self.buffer:sub(start, nl - 1)
      table.insert(lines, line)
      start = nl + 1
    end

    self.buffer = self.buffer:sub(start)

    for _, line in ipairs(lines) do
      self:_parse_line(line)
    end
  end

  function instance:_parse_line(line)
    if line == "" then
      return
    end
    local ok, event = pcall(vim.json.decode, line)
    if not ok then
      if self.on_error then
        self.on_error("JSON parse error: " .. tostring(event), line)
      end
      return
    end
    if self.on_event then
      self.on_event(event)
    end
  end

  function instance:reset()
    self.buffer = ""
  end

  return instance
end

return M