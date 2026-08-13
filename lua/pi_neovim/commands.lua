-- User commands for Pi Neovim plugin
-- Implements :PiPrompt, :PiStart, :PiStop, :PiRestart, :PiStatus, :PiContext

local M = {}

local ui = require("pi_neovim.ui")
local response = require("pi_neovim.response")

-- Streaming response state
local streaming_state = {
  buf = nil,
  win = nil,
  request_id = nil,
}

-- Send prompt to Pi and show response
local function pi_prompt(prompt_text, use_visual_selection)
  local process = require("pi_neovim.process")
  local context = require("pi_neovim.context")

  if not process.is_running() then
    vim.notify("Pi agent not running. Use :PiStart to start it.", vim.log.levels.WARN)
    return
  end

  -- Get context
  local ctx = context.get_for_prompt()

  -- Add visual selection if requested
  if use_visual_selection then
    local selection = context.get_visual_selection and context.get_visual_selection()
    if selection then
      ctx.selection = selection
    end
  end

  -- Build request
  local request_data = {
    type = "prompt",
    context = ctx,
    prompt = prompt_text or "",
  }

  -- Create float window for response
  local buf, win = ui.create_float({
    title = " Pi Response ",
    filetype = "markdown",
  })

  streaming_state.buf = buf
  streaming_state.win = win

  -- Set initial content
  ui.set_content(buf, { "# Pi Response", "", "..." })

  -- Set up streaming handler
  local request_id = process.send_request(request_data, function(resp, error)
    streaming_state.request_id = nil

    if error then
      ui.set_content(buf, { "# Error", "", error })
      return
    end

    if not resp then
      ui.set_content(buf, { "# Error", "", "No response from Pi" })
      return
    end

    -- Format response
    local lines = { "# Pi Response", "" }
    if resp.text then
      for _, line in ipairs(vim.split(resp.text, "\n")) do
        table.insert(lines, line)
      end
    elseif resp.message then
      table.insert(lines, resp.message)
    else
      table.insert(lines, vim.inspect(resp))
    end

    ui.set_content(buf, lines)
  end, 60000)

  if not request_id then
    ui.close(win)
    vim.notify("Failed to send prompt to Pi", vim.log.levels.ERROR)
  end
end

-- Command implementations
M.commands = {}

function M.commands.PiPrompt(opts)
  local prompt = opts.args
  local use_visual = opts.bang -- :PiPrompt! uses visual selection
  pi_prompt(prompt, use_visual)
end

function M.commands.PiStart()
  local process = require("pi_neovim.process")
  local pi_neovim = require("pi_neovim")
  local started = process.start({ cmd = pi_neovim.config.pi_cmd })
  if started then
    vim.notify("Pi agent started", vim.log.levels.INFO)
  else
    vim.notify("Failed to start Pi agent", vim.log.levels.ERROR)
  end
end

function M.commands.PiStop()
  local process = require("pi_neovim.process")
  process.stop()
end

function M.commands.PiRestart()
  local process = require("pi_neovim.process")
  local pi_neovim = require("pi_neovim")
  process.stop()
  vim.defer_fn(function()
    local started = process.start({ cmd = pi_neovim.config.pi_cmd })
    if started then
      vim.notify("Pi agent restarted", vim.log.levels.INFO)
    else
      vim.notify("Failed to restart Pi agent", vim.log.levels.ERROR)
    end
  end, 500)
end

function M.commands.PiStatus()
  local process = require("pi_neovim.process")
  local running = process.is_running()
  local job_id = process.get_job_id()
  local pending = process.pending_request_count()

  local lines = {
    "Pi Agent Status",
    "===============",
    "Running: " .. (running and "Yes" or "No"),
    "Job ID: " .. (job_id or "N/A"),
    "Pending Requests: " .. pending,
  }
  ui.show_status(lines)
end

function M.commands.PiContext()
  local context = require("pi_neovim.context")
  local ctx = context.get_for_prompt()
  local markdown = context.format_as_markdown(ctx)

  ui.show_context(markdown)
end

-- Setup function - creates user commands
function M.setup()
  -- :PiPrompt [prompt] - send prompt to Pi
  vim.api.nvim_create_user_command("PiPrompt", function(opts)
    M.commands.PiPrompt(opts)
  end, {
    nargs = "?",
    bang = true,
    desc = "Send prompt to Pi agent (use ! for visual selection)",
  })

  -- :PiStart - start Pi agent
  vim.api.nvim_create_user_command("PiStart", function()
    M.commands.PiStart()
  end, {
    desc = "Start Pi agent process",
  })

  -- :PiStop - stop Pi agent
  vim.api.nvim_create_user_command("PiStop", function()
    M.commands.PiStop()
  end, {
    desc = "Stop Pi agent process",
  })

  -- :PiRestart - restart Pi agent
  vim.api.nvim_create_user_command("PiRestart", function()
    M.commands.PiRestart()
  end, {
    desc = "Restart Pi agent process",
  })

  -- :PiStatus - show agent status
  vim.api.nvim_create_user_command("PiStatus", function()
    M.commands.PiStatus()
  end, {
    desc = "Show Pi agent status",
  })

  -- :PiContext - show current context
  vim.api.nvim_create_user_command("PiContext", function()
    M.commands.PiContext()
  end, {
    desc = "Show context that would be sent to Pi",
  })

  -- Apply keymaps from config
  M.apply_keymaps()
end

-- Apply keymaps from plugin config
function M.apply_keymaps()
  local pi_neovim = require("pi_neovim")
  local keymaps = pi_neovim.config.keymaps or {}

  for _, km in ipairs(keymaps) do
    if #km >= 3 then
      local mode = km[1]
      local lhs = km[2]
      local rhs = km[3]
      local opts = km[4] or {}
      if type(opts) == "string" then
        opts = { desc = opts }
      end
      vim.keymap.set(mode, lhs, rhs, opts)
    end
  end
end

return M