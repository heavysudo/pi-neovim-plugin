-- UI utilities for Pi Neovim plugin
-- Floating windows, syntax highlighting, response display

local M = {}

-- Default float configuration
local float_config = {
  border = "rounded",
  max_width = 100,
  max_height = 30,
  title = " Pi ",
  title_pos = "center",
}

-- Set float configuration
function M.set_config(config)
  float_config = vim.tbl_deep_extend("force", float_config, config or {})
end

-- Create a floating window
-- opts: { title, filetype, width, height, border, on_close }
-- Returns: buf, win
function M.create_float(opts)
  opts = opts or {}

  local width = opts.width or float_config.max_width
  local height = opts.height or float_config.max_height
  width = math.min(width, vim.o.columns - 4)
  height = math.min(height, vim.o.lines - 4)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false

  if opts.filetype then
    vim.bo[buf].filetype = opts.filetype
  end

  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = opts.border or float_config.border,
    title = opts.title or float_config.title,
    title_pos = opts.title_pos or float_config.title_pos,
  }

  local win = vim.api.nvim_open_win(buf, true, win_config)

  -- Set up keymaps
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if opts.on_close then
      opts.on_close()
    end
  end

  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true, silent = true })

  -- Scroll bindings
  vim.keymap.set("n", "<C-d>", "<C-d>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-u>", "<C-u>", { buffer = buf, silent = true })
  vim.keymap.set("n", "j", "j", { buffer = buf, silent = true })
  vim.keymap.set("n", "k", "k", { buffer = buf, silent = true })

  -- Copy current line/selection
  vim.keymap.set("n", "yy", function()
    local line = vim.api.nvim_get_current_line()
    vim.fn.setreg("+", line)
    vim.notify("Copied to clipboard", vim.log.levels.INFO)
  end, { buffer = buf, silent = true, desc = "Copy line to clipboard" })

  vim.keymap.set("v", "y", function()
    vim.cmd('normal! "++y')
    vim.notify("Copied to clipboard", vim.log.levels.INFO)
  end, { buffer = buf, silent = true, desc = "Copy selection to clipboard" })

  -- Insert at cursor (in original window)
  vim.keymap.set("n", "i", function()
    local line = vim.api.nvim_get_current_line()
    close()
    vim.api.nvim_put({ line }, "l", true, true)
  end, { buffer = buf, silent = true, desc = "Insert line at cursor" })

  return buf, win
end

-- Set content of float buffer
function M.set_content(buf, lines)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return true
end

-- Append content to float buffer (for streaming)
function M.append_content(buf, lines)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.list_extend(current, lines)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, current)
  return true
end

-- Close float window
function M.close(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
    return true
  end
  return false
end

-- Show response in float (markdown with code blocks)
function M.show_response(response_text, opts)
  opts = opts or {}
  local buf, win = M.create_float({
    title = opts.title or " Pi Response ",
    filetype = "markdown",
    width = opts.width,
    height = opts.height,
    on_close = opts.on_close,
  })

  local lines = {}
  if opts.header then
    table.insert(lines, opts.header)
    table.insert(lines, "")
  end

  -- Split response into lines
  for _, line in ipairs(vim.split(response_text, "\n")) do
    table.insert(lines, line)
  end

  M.set_content(buf, lines)

  return buf, win
end

-- Show error in float
function M.show_error(error_msg, opts)
  opts = opts or {}
  local buf, win = M.create_float({
    title = opts.title or " Pi Error ",
    filetype = "markdown",
    width = opts.width or 80,
    height = opts.height or 15,
    on_close = opts.on_close,
  })

  local lines = {
    "# Error",
    "",
    error_msg,
    "",
    "Press `q` or `<Esc>` to close",
  }

  M.set_content(buf, lines)

  return buf, win
end

-- Show context in float
function M.show_context(markdown_text, opts)
  opts = opts or {}
  local buf, win = M.create_float({
    title = opts.title or " Pi Context ",
    filetype = "markdown",
    width = opts.width or 100,
    height = opts.height or 40,
    on_close = opts.on_close,
  })

  local lines = vim.split(markdown_text, "\n")
  M.set_content(buf, lines)

  return buf, win
end

-- Show status in float
function M.show_status(status_lines, opts)
  opts = opts or {}
  local buf, win = M.create_float({
    title = opts.title or " Pi Status ",
    filetype = "text",
    width = opts.width or 60,
    height = opts.height or 15,
    on_close = opts.on_close,
  })

  M.set_content(buf, status_lines)

  return buf, win
end

return M