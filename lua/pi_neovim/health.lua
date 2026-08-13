-- Health check for Pi Neovim plugin
-- Run with :checkhealth pi_neovim

local M = {}

local function check_pi_binary()
  local pi_path = vim.fn.exepath("pi")
  if pi_path == "" then
    vim.health.error("Pi binary not found in PATH")
    vim.health.info("Install Pi from https://pi.dev or ensure it's in your PATH")
    return false
  end

  vim.health.ok("Pi binary found: " .. pi_path)

  -- Try to get version
  local version = vim.fn.system("pi --version 2>&1")
  if vim.v.shell_error == 0 then
    vim.health.ok("Pi version: " .. vim.trim(version))
  else
    vim.health.warn("Could not determine Pi version: " .. version)
  end

  return true
end

local function check_neovim_version()
  local version = vim.version()
  local version_str = string.format("%d.%d.%d", version.major, version.minor, version.patch)
  if version.major > 0 or (version.major == 0 and version.minor >= 5) then
    vim.health.ok("Neovim version: " .. version_str)
    return true
  else
    vim.health.error("Neovim version too old: " .. version_str .. " (need >= 0.5.0)")
    return false
  end
end

local function check_nvim_cmp()
  local has_cmp, cmp = pcall(require, "cmp")
  if not has_cmp then
    vim.health.warn("nvim-cmp not installed - autocomplete will not work")
    vim.health.info("Install hrsh7th/nvim-cmp for autocomplete support")
    return false
  end

  vim.health.ok("nvim-cmp found")

  -- Check if our source is registered
  local sources = cmp.get_config().sources or {}
  local has_pi_source = false
  for _, s in ipairs(sources) do
    if s.name == "pi" then
      has_pi_source = true
      break
    end
  end

  if has_pi_source then
    vim.health.ok("Pi cmp source registered")
  else
    vim.health.info("Pi cmp source not yet registered (will be registered on setup)")
  end

  return true
end

local function check_plugin_config()
  local pi_neovim = require("pi_neovim")
  local config = pi_neovim.config

  if not config or vim.tbl_isempty(config) then
    vim.health.warn("Plugin not configured (setup() not called)")
    return false
  end

  vim.health.ok("Plugin configured")

  -- Check pi_cmd
  if config.pi_cmd and #config.pi_cmd > 0 then
    vim.health.ok("Pi command: " .. table.concat(config.pi_cmd, " "))
  else
    vim.health.warn("No Pi command configured")
  end

  -- Check autocomplete config
  if config.autocomplete then
    if config.autocomplete.enabled then
      vim.health.ok("Autocomplete enabled")
      if config.autocomplete.filetypes and #config.autocomplete.filetypes > 0 then
        vim.health.info("Autocomplete filetypes: " .. table.concat(config.autocomplete.filetypes, ", "))
      else
        vim.health.info("Autocomplete enabled for all filetypes")
      end
    else
      vim.health.info("Autocomplete disabled")
    end
  end

  -- Check keymaps
  if config.keymaps and #config.keymaps > 0 then
    vim.health.ok("Keymaps configured (" .. #config.keymaps .. " mappings)")
  else
    vim.health.info("No keymaps configured")
  end

  return true
end

local function check_process()
  local process = require("pi_neovim.process")

  if process.is_running() then
    vim.health.ok("Pi agent process running (job ID: " .. (process.get_job_id() or "unknown") .. ")")
    local pending = process.pending_request_count()
    if pending > 0 then
      vim.health.info("Pending requests: " .. pending)
    end
  else
    vim.health.warn("Pi agent process not running")
    vim.health.info("Run :PiStart to start the agent")
  end

  return process.is_running()
end

local function check_rpc_mode()
  local pi_neovim = require("pi_neovim")
  local cmd = pi_neovim.config.pi_cmd or {}

  local has_rpc = false
  for _, arg in ipairs(cmd) do
    if arg == "--mode" then
      -- Next arg should be rpc
    elseif arg == "rpc" then
      has_rpc = true
    end
  end

  if has_rpc then
    vim.health.ok("Pi RPC mode enabled")
  else
    vim.health.warn("Pi RPC mode not detected in command")
    vim.health.info("Ensure pi_cmd includes '--mode rpc' for plugin to work")
  end

  return has_rpc
end

function M.check()
  vim.health.start("Pi Neovim Plugin")

  check_neovim_version()
  check_pi_binary()
  check_nvim_cmp()
  check_plugin_config()
  check_rpc_mode()
  check_process()

  vim.health.start("Pi Neovim Plugin - Summary")
  vim.health.info("Run :PiStart to start the Pi agent")
  vim.health.info("Run :PiPrompt <prompt> to send a prompt")
  vim.health.info("Run :PiContext to see what context is sent")
  vim.health.info("Run :PiStatus to check agent status")
end

return M