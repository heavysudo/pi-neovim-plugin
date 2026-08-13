-- Process manager for Pi agent in Neovim
-- Handles spawning, monitoring, and stopping the Pi agent process in RPC mode.

local M = {}

-- Configuration
M.config = {
  -- Command to run Pi (can be overridden)
  cmd = { "pi", "--mode", "rpc", "--no-session" },
  -- Optional: additional args can be added here or via config
  -- We'll allow the user to pass extra args through the plugin config.
}

-- State
M.state = {
  -- The job ID of the Pi process (from vim.fn.jobstart)
  job_id = nil,
  -- Channels for stdout and stderr
  stdout = nil,
  stderr = nil,
  -- Whether the process is running
  is_running = false,
  -- Buffer for stdout data (we'll parse JSONL)
  stdout_buffer = "",
  -- Buffer for stderr data
  stderr_buffer = "",
  -- Callback functions for events
  on_stdout = nil, -- function(chunk)
  on_stderr = nil, -- function(chunk)
  on_exit = nil,   -- function(code)
}

-- Start the Pi agent process
function M.start(config)
  -- Stop any existing process first
  M.stop()

  -- Merge config
  if config then
    if config.cmd then
      M.config.cmd = config.cmd
    end
    -- We'll assume config may contain other options, but for now just cmd.
  end

  -- Spawn the process
  local job_id = vim.fn.jobstart(M.config.cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = vim.schedule_wrap(function(_, data, _)
      if data then
        for _, chunk in ipairs(data) do
          if chunk ~= "" then
            M.state.stdout_buffer = M.state.stdout_buffer .. chunk
            if M.state.on_stdout then
              M.state.on_stdout(chunk)
            end
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
  M.state.stdout_buffer = ""
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
function M.set_on_stdout(callback)
  M.state.on_stdout = callback
end

function M.set_on_stderr(callback)
  M.state.on_stderr = callback
end

function M.set_on_exit(callback)
  M.state.on_exit = callback
end

-- Write data to the process's stdin
-- data: string to write (should be a JSONL line, i.e., end with \n)
function M.stdin_write(data)
  if not M.state.is_running or not M.state.job_id then
    vim.notify("Cannot write to Pi agent: not running", vim.log.levels.WARN)
    return false
  end
  -- Use vim.fn.chansend? Actually, jobstart with default stdin is a pipe, we can use vim.fn.chansend?
  -- We'll use vim.fn.chansend if we have a channel, but jobstart returns a job ID, not a channel.
  -- Alternatively, we can use vim.fn.jobsend(job_id, data) but that doesn't exist.
  -- We'll use the job ID with vim.fn.chansend? Actually, the job ID can be used as a channel?
  -- From Neovim docs: jobstart returns a job ID, and you can use chan_send(job_id, ...) to send data.
  -- Let's use vim.fn.chansend.
  vim.fn.chansend(M.state.job_id, data)
  return true
end

-- Read buffered stdout (and clear buffer)
function M.read_stdout_buffer()
  local buf = M.state.stdout_buffer
  M.state.stdout_buffer = ""
  return buf
end

-- Read buffered stderr (and clear buffer)
function M.read_stderr_buffer()
  local buf = M.state.stderr_buffer
  M.state.stderr_buffer = ""
  return buf
end

return M