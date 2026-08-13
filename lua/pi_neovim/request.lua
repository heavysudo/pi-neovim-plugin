-- Request/Response management for Pi RPC protocol
-- Tracks pending requests, handles timeouts, correlates responses

local M = {}

-- Request registry
local pending_requests = {}
local request_counter = 0

-- Configuration
local config = {
  default_timeout = 30000, -- 30 seconds
}

-- Generate unique request ID
local function generate_id()
  request_counter = request_counter + 1
  return string.format("req-%d-%d", os.time(), request_counter)
end

-- Register a new pending request
-- params: { type, context, callback, timeout }
-- Returns request ID
function M.register(params)
  local id = params.id or generate_id()
  local timeout = params.timeout or config.default_timeout

  local request = {
    id = id,
    type = params.type,
    context = params.context,
    callback = params.callback,
    timestamp = os.time(),
    timeout_timer = nil,
  }

  -- Set up timeout
  if timeout > 0 then
    request.timeout_timer = vim.defer_fn(function()
      M.handle_timeout(id)
    end, timeout)
  end

  pending_requests[id] = request
  return id
end

-- Handle response from Pi
-- Matches response to pending request by ID
function M.handle_response(response)
  local id = response.id or response.request_id
  if not id then
    -- No ID - might be a notification/event
    return false, "no request id in response"
  end

  local request = pending_requests[id]
  if not request then
    return false, "no pending request for id: " .. id
  end

  -- Clear timeout
  if request.timeout_timer then
    request.timeout_timer:stop()
    request.timeout_timer = nil
  end

  -- Remove from pending
  pending_requests[id] = nil

  -- Call callback with response
  if request.callback then
    local ok, err = pcall(request.callback, response, nil)
    if not ok then
      vim.notify("Request callback error: " .. tostring(err), vim.log.levels.ERROR)
    end
  end

  return true
end

-- Handle request timeout
function M.handle_timeout(id)
  local request = pending_requests[id]
  if not request then
    return
  end

  pending_requests[id] = nil

  if request.callback then
    local ok, err = pcall(request.callback, nil, "Request timeout after " .. config.default_timeout .. "ms")
    if not ok then
      vim.notify("Timeout callback error: " .. tostring(err), vim.log.levels.ERROR)
    end
  end
end

-- Cancel a pending request
function M.cancel(id)
  local request = pending_requests[id]
  if not request then
    return false
  end

  if request.timeout_timer then
    request.timeout_timer:stop()
    request.timeout_timer = nil
  end

  pending_requests[id] = nil
  return true
end

-- Cancel all pending requests
function M.cancel_all()
  for id, request in pairs(pending_requests) do
    if request.timeout_timer then
      request.timeout_timer:stop()
    end
  end
  pending_requests = {}
end

-- Get pending request count
function M.pending_count()
  local count = 0
  for _ in pairs(pending_requests) do
    count = count + 1
  end
  return count
end

-- List pending requests (for debugging)
function M.list_pending()
  local list = {}
  for id, request in pairs(pending_requests) do
    table.insert(list, {
      id = id,
      type = request.type,
      timestamp = request.timestamp,
      age_ms = (os.time() - request.timestamp) * 1000,
    })
  end
  return list
end

-- Set default timeout
function M.set_default_timeout(ms)
  config.default_timeout = ms
end

-- Send a request to Pi via process module
-- This is a convenience function that registers and sends
function M.send(process_module, request_data, callback, timeout)
  local id = generate_id()
  local payload = vim.tbl_extend("force", request_data, { id = id })

  M.register({
    id = id,
    type = request_data.type,
    context = request_data.context,
    callback = callback,
    timeout = timeout,
  })

  local json = vim.json.encode(payload) .. "\n"
  local ok = process_module.stdin_write(json)
  if not ok then
    M.cancel(id)
    if callback then
      callback(nil, "Failed to write to Pi process")
    end
    return nil
  end

  return id
end

return M