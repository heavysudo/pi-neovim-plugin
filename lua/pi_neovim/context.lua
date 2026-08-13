-- Context gathering for Pi Neovim plugin
-- Gathers buffer, cursor, workspace context for Pi requests

local M = {}

-- Configuration reference (set by init.lua)
M.config = {
  lines_around_cursor = 0,
  max_buffer_size = 0,
}

-- Set config from plugin config
function M.set_config(config)
  M.config = vim.tbl_deep_extend("force", M.config, config or {})
end

-- Get visual selection text (if any)
function M.get_visual_selection()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then -- \22 is Ctrl-V
    return nil
  end

  -- Get selection range
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if #lines == 0 then
    return nil
  end

  -- Handle partial line selection
  if #lines == 1 then
    lines[1] = lines[1]:sub(start_col, end_col)
  else
    lines[1] = lines[1]:sub(start_col)
    lines[#lines] = lines[#lines]:sub(1, end_col)
  end

  return table.concat(lines, "\n")
end

-- Get buffer content with optional line window around cursor
local function get_buffer_content(bufnr, lines_around_cursor, max_buffer_size)
  bufnr = bufnr or 0
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  local start_line, end_line
  if lines_around_cursor and lines_around_cursor > 0 then
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    start_line = math.max(1, cursor_line - lines_around_cursor)
    end_line = math.min(total_lines, cursor_line + lines_around_cursor)
  else
    start_line = 1
    end_line = total_lines
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local content = table.concat(lines, "\n")

  -- Apply max buffer size limit
  if max_buffer_size and max_buffer_size > 0 and #content > max_buffer_size then
    -- Truncate from the middle, keeping start and end
    local half = math.floor(max_buffer_size / 2)
    content = content:sub(1, half) .. "\n... [truncated] ...\n" .. content:sub(-half)
  end

  return {
    content = content,
    start_line = start_line,
    end_line = end_line,
    total_lines = total_lines,
  }
end

-- Get workspace info (cwd, git root, project files)
local function get_workspace_info()
  local cwd = vim.fn.getcwd()
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
  if git_root and git_root ~= "" and not git_root:match("fatal") then
    git_root = vim.trim(git_root)
  else
    git_root = nil
  end

  return {
    cwd = cwd,
    git_root = git_root,
  }
end

-- Get recent buffers (modified, listed)
local function get_recent_buffers(limit)
  limit = limit or 5
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" then
        table.insert(buffers, {
          name = name,
          modified = vim.bo[buf].modified,
          filetype = vim.bo[buf].filetype,
        })
      end
    end
  end
  -- Sort: modified first, then by last used
  table.sort(buffers, function(a, b)
    if a.modified ~= b.modified then
      return a.modified
    end
    return false
  end)
  return vim.list_slice(buffers, 1, limit)
end

-- Gather context for autocomplete
function M.get_for_completion()
  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)

  local selection = M.get_visual_selection()
  local buf_content = get_buffer_content(bufnr, M.config.lines_around_cursor, M.config.max_buffer_size)
  local workspace = get_workspace_info()

  local context = {
    buffer = {
      content = buf_content.content,
      cursor = {
        line = cursor[1],
        column = cursor[2],
      },
      filetype = vim.bo[bufnr].filetype,
      name = vim.api.nvim_buf_get_name(bufnr),
      start_line = buf_content.start_line,
      end_line = buf_content.end_line,
      total_lines = buf_content.total_lines,
    },
    workspace = workspace,
  }

  if selection then
    context.selection = selection
  end

  return context
end

-- Gather context for general prompt
function M.get_for_prompt()
  local completion_ctx = M.get_for_completion()

  -- Add recent buffers for prompt context
  completion_ctx.recent_buffers = get_recent_buffers(10)

  return completion_ctx
end

-- Format context as Markdown for Pi prompt
function M.format_as_markdown(context)
  local lines = {}

  table.insert(lines, "## Buffer Context")
  table.insert(lines, "")
  table.insert(lines, "**File:** " .. (context.buffer.name ~= "" and context.buffer.name or "[unnamed]"))
  table.insert(lines, "**Filetype:** " .. context.buffer.filetype)
  table.insert(lines, "**Cursor:** Line " .. context.buffer.cursor.line .. ", Col " .. context.buffer.cursor.column)
  table.insert(lines, "**Lines:** " .. context.buffer.start_line .. "-" .. context.buffer.end_line .. " of " .. context.buffer.total_lines)
  table.insert(lines, "")

  if context.selection then
    table.insert(lines, "## Selection")
    table.insert(lines, "")
    table.insert(lines, "```" .. context.buffer.filetype)
    table.insert(lines, context.selection)
    table.insert(lines, "```")
    table.insert(lines, "")
  end

  table.insert(lines, "## Buffer Content")
  table.insert(lines, "")
  table.insert(lines, "```" .. context.buffer.filetype)
  table.insert(lines, context.buffer.content)
  table.insert(lines, "```")
  table.insert(lines, "")

  if context.workspace then
    table.insert(lines, "## Workspace")
    table.insert(lines, "")
    table.insert(lines, "- **CWD:** " .. context.workspace.cwd)
    if context.workspace.git_root then
      table.insert(lines, "- **Git Root:** " .. context.workspace.git_root)
    end
    table.insert(lines, "")
  end

  if context.recent_buffers then
    table.insert(lines, "## Recent Buffers")
    table.insert(lines, "")
    for _, buf in ipairs(context.recent_buffers) do
      local mod = buf.modified and " [modified]" or ""
      table.insert(lines, "- " .. buf.name .. mod)
    end
    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

-- Format context as JSON for Pi RPC
function M.format_as_json(context)
  return vim.json.encode(context)
end

return M