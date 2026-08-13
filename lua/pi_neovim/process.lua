-- Process manager for Pi agent in Neovim
-- Handles spawning, monitoring, and stopping the Pi agent process in RPC mode.
-- Integrates JSONL parsing and request/response correlation.

local M = {}

local jsonl = require("pi_neovim.jsonl")
local request = require("pi_neovim.request")

-- Configuration
M.config = {
  -- Command to run Pi (can be overridden)
  cmd = { "pi", "--mode", "rpc", "--no-session" },
}

-- State
M.state = {
  job_id = nil,
  is_running = false,
  stderr_buffer = "",
  -- Callbacks
  on_stderr = nil,    -- function(chunk)
  on_exit = nil,      -- function(code)
  on_event = nil,     -- function(event) - parsed JSONL events
  on_error = nil,     -- function(err, raw_line) - JSONL parse errors
}

-- JSONL parser instance
local jsonl_parser = jsonl.new({
  on_event = function(event)
    -- First try to correlate with pending request
    local handled = request.handle_response(event)
    if not handled then
      -- Not a response to a request - treat as event/notification
      if M.state.on_event then
        M.state.on_event(event)
      end
    end
  end,
  on_error = function(err, raw_line)
    if M.state.on_error then
      M.state.on_error(err, raw_line)
    end
  end,
})

-- Start the Pi agent process
function M.start(config)
  -- Stop any existing process first
  M.stop()

  -- Merge config
  if config then
    if config.cmd then
      M.config.cmd = config.cmd
    end
  end

  -- Reset JSONL parser
  jsonl_parser:reset()
  request.cancel_all()

  -- Spawn the process
  local job_id = vim.fn.jobstart(M.config.cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = vim.schedule_wrap(function(_, data, _)
      if data then
        for _, chunk in ipairs(data) do
          if chunk ~= "" then
            -- Feed chunk to JSONL parser
            jsonl_parser:process_chunk(chunk)
          end
        end
      end
    end),
    on_stderr = vim.schedule_wrap(function(_, data, _)
      if data then
        for _, chunk in ipairs(data) do
          if chunk ~= "" then
            M.state.stderr_buffer = M.state.stderr_buffer .. chunk
            if M.state.on_stderr then
              M.state.on_stderr(chunk)
            end
          end
        end
      end
    end),
    on_exit = vim.schedule_wrap(function(_, code, _)
      M.state.is_running = false
      M.state.job_id = nil
      -- Cancel all pending requests on exit
      request.cancel_all()
      if M.state.on_exit then
        M.state.on_exit(code)
      end
    end),
  })

  if job_id <= 0 then
    vim.notify("Failed to start Pi agent: job_id " .. job_id, vim.log.levels.ERROR)
    return false
  end

  M.state.job_id = job_id
  M.state.is_running = true
  M.state.stderr_buffer = ""

  vim.notify("Pi agent started (job ID: " .. job_id .. ")", vim.log.levels.INFO)
  return true
end

-- Stop the Pi agent process
function M.stop()
  if M.state.is_running and M.state.job_id then
    vim.fn.jobstop(M.state.job_id)
    M.state.is_running = false
    M.state.job_id = nil
    request.cancel_all()
    vim.notify("Pi agent stopped", vim.log.levels.INFO)
  end
end

-- Check if the process is running
function M.is_running()
  return M.state.is_running
end

-- Get the job ID
function M.get_job_id()
  return M.state.job_id
end

-- Set callbacks
function M.set_on_stderr(callback)
  M.state.on_stderr = callback
end

function M.set_on_exit(callback)
  M.state.on_exit = callback
end

-- Set event callback (for parsed JSONL events not tied to requests)
function M.set_on_event(callback)
  M.state.on_event = callback
end

-- Set JSONL parse error callback
function M.set_on_error(callback)
  M.state.on_error = callback
end

-- Write data to the process's stdin
-- data: string to write (should be a JSONL line, i.e., end with \n)
function M.stdin_write(data)
  if not M.state.is_running or not M.state.job_id then
    vim.notify("Cannot write to Pi agent: not running", vim.log.levels.WARN)
    return false
  end
  -- jobstart returns a job ID which can be used with chansend
  vim.fn.chansend(M.state.job_id, data)
  return true
end

-- Send a request and register callback for response
-- request_data: table with at least { type = "..." }
-- callback: function(response, error)
-- timeout: optional timeout in ms
-- Returns request ID or nil on failure
function M.send_request(request_data, callback, timeout)
  return request.send(M, request_data, callback, timeout)
end

-- Cancel a pending request by ID
function M.cancel_request(id)
  return request.cancel(id)
end

-- Cancel all pending requests
function M.cancel_all_requests()
  request.cancel_all()
end

-- Get pending request count
function M.pending_request_count()
  return request.pending_count()
end

-- Read buffered stderr (and clear buffer)
function M.read_stderr_buffer()
  local buf = M.state.stderr_buffer
  M.state.stderr_buffer = ""
  return buf
end

-- Expose request module for advanced usage
M.request = request

return M