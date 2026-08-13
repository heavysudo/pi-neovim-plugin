# Pi Neovim Plugin

This plugin integrates the [Pi coding agent](https://pi.dev) into Neovim to provide context-aware autocomplete and prompting capabilities via Pi's RPC mode.

## Features

- **Context-aware Autocomplete**: Uses Pi to provide code completions based on your current buffer, cursor position, and workspace.
- **Prompting**: Send arbitrary prompts to Pi from Neovim and see the results in a floating window with markdown rendering.
- **Visual Selection Support**: Use `:PiPrompt!` with visual selection to include selected text in your prompt.
- **Context Inspection**: View exactly what context is sent to Pi with `:PiContext`.
- **Process Management**: Automatically starts/stops the Pi agent process with `:PiStart`, `:PiStop`, `:PiRestart`.
- **Status Monitoring**: Check agent status with `:PiStatus`.
- **Health Check**: Run `:checkhealth pi_neovim` to verify installation and configuration.
- **LazyVim Integration**: Works seamlessly with LazyVim.
- **JSONL Protocol**: Robust JSONL parsing for reliable communication with Pi.

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) (recommended for LazyVim users)

Add the following to your LazyVim configuration (e.g., in `lua/plugins/pi-neovim.lua`):

```lua
{
  "heavysudo/pi-neovim-plugin",
  dependencies = { "nvim-cmp" }, -- optional but recommended for autocomplete
  opts = {},
  config = function(_, opts)
    require("pi_neovim").setup(opts)
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "heavysudo/pi-neovim-plugin",
  requires = { "nvim-cmp" },
  config = function()
    require("pi_neovim").setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'heavysudo/pi-neovim-plugin', { 'do': ':PiStart' }
Plug 'hrsh7th/nvim-cmp' " Optional, for autocomplete
```

Then run `:PlugInstall` and `:PiStart` to start the Pi agent.

## Configuration

The plugin can be configured by passing a table to `setup()`. The default configuration is:

```lua
{
  -- Pi command and arguments
  pi_cmd = { "pi", "--mode", "rpc", "--no-session" },

  -- Context gathering options
  context = {
    -- How many lines around the cursor to send for autocomplete? (0 for whole buffer)
    lines_around_cursor = 0,
    -- Maximum buffer size to send (in bytes), 0 for no limit
    max_buffer_size = 0,
  },

  -- Autocomplete options
  autocomplete = {
    -- Enable autocomplete source
    enabled = true,
    -- Filetypes to enable autocomplete for (empty for all)
    filetypes = {},
    -- Minimum trigger length (characters) before requesting completion
    trigger_length = 2,
  },

  -- Keybindings (optional)
  keymaps = {
    { "n", "<leader>pp", "<cmd>PiPrompt<cr>", desc = "Pi Prompt" },
  },

  -- UI options
  ui = {
    float = { border = "rounded", max_width = 100, max_height = 30 },
    streaming = true,
  },

  -- Request behavior
  request = {
    timeout = 30000,
    retry = 1,
  },

  -- Logging
  log_level = "info",
}
```

You can override any of these options when calling `setup()`.

### Example: Custom Pi Model

To use a specific model with Pi:

```lua
require("pi_neovim").setup({
  pi_cmd = { "pi", "--mode", "rpc", "--no-session", "--model", "claude-3-opus-20240229" },
})
```

### Example: Autocomplete for Specific Filetypes Only

```lua
require("pi_neovim").setup({
  autocomplete = {
    enabled = true,
    filetypes = { "lua", "python", "javascript", "typescript", "go", "rust" },
    trigger_length = 3,
  },
})
```

### Example: Custom UI Settings

```lua
require("pi_neovim").setup({
  ui = {
    float = { border = "single", max_width = 120, max_height = 40 },
    streaming = true,
  },
  request = {
    timeout = 60000,
    retry = 2,
  },
})
```

### Disabling Default Keymaps

The plugin does not enforce any keymaps by default to avoid conflicts. The example keymap in the default config is just that — an example. To use your own keymaps, either:

1. Override the `keymaps` option in your `setup()` call with your preferred mappings, or
2. Set `keymaps = {}` to disable the example and set your own mappings separately using `vim.keymap.set`.

## Keymapping Recommendations

Since `<leader>p` mappings are often used by other plugins, here are some alternative keymap suggestions:

### Option 1: Use `<leader>op` (o for "open" or "option")

```lua
{ "n", "<leader>op", "<cmd>PiPrompt<cr>", desc = "Prompt Pi" },
{ "x", "<leader>op", "<cmd>PiPrompt<cr>", desc = "Prompt Pi with selection" },
```

### Option 2: Use `<leader>np` (n for "Neovim" or "new")

```lua
{ "n", "<leader>np", "<cmd>PiPrompt<cr>", desc = "Prompt Pi" },
{ "x", "<leader>np", "<cmd>PiPrompt<cr>", desc = "Prompt Pi with selection" },
```

### Option 3: Use a function key (less mnemonic but guaranteed free)

```lua
{ "n", "<F5>", "<cmd>PiStart<cr>", desc = "Start Pi agent" },
{ "n", "<F6>", "<cmd>PiStop<cr>", desc = "Stop Pi agent" },
{ "n", "<F7>", "<cmd>PiPrompt<cr>", desc = "Prompt Pi" },
{ "x", "<F7>", "<cmd>PiPrompt<cr>", desc = "Prompt Pi with selection" },
```

### Option 4: Use `<localleader>p` if you have a local leader defined

```lua
{ "n", "<localleader>pp", "<cmd>PiPrompt<cr>", desc = "Prompt Pi" },
{ "x", "<localleader>pp", "<cmd>PiPrompt<cr>", desc = "Prompt Pi with selection" },
```

### Process Management Keymaps (examples)

You may also want to set up keymaps for starting, stopping, and checking the Pi agent:

```lua
{ "n", "<leader>ps", "<cmd>PiStart<cr>", desc = "Start Pi agent" },
{ "n", "<leader>pk", "<cmd>PiStop<cr>", desc = "Stop Pi agent" },
{ "n", "<leader>pr", "<cmd>PiRestart<cr>", desc = "Restart Pi agent" },
{ "n", "<leader>pS", "<cmd>PiStatus<cr>", desc = "Pi agent status" },
```

## Commands

| Command | Description |
| --------- | ------------- |
| `:PiPrompt [prompt]` | Send prompt to Pi, show response in floating window |
| `:PiPrompt!` | Same but includes visual selection as context |
| `:PiStart` | Start Pi agent process |
| `:PiStop` | Stop Pi agent process |
| `:PiRestart` | Restart Pi agent process |
| `:PiStatus` | Show agent status (running/stopped, job ID, pending requests) |
| `:PiContext` | Show current context that would be sent to Pi |
| `:checkhealth pi_neovim` | Run health check for the plugin |

### Usage Examples

```vim
" Send a prompt with context
:PiPrompt Explain this function

" Send prompt with visual selection (select text first, then run)
:PiPrompt! What does this code do?

" Check agent status
:PiStatus

" View context being sent
:PiContext

" Restart agent if it's stuck
:PiRestart

" Run health check
:checkhealth pi_neovim
```

## Autocomplete

Once the plugin is set up and nvim-cmp is installed, autocomplete will work automatically in supported filetypes. The plugin registers a source named "pi" with nvim-cmp.

The autocomplete source:

- Respects `autocomplete.filetypes` (empty = all filetypes)
- Respects `autocomplete.trigger_length` (minimum prefix length)
- Sends buffer context, cursor position, and trigger character to Pi
- Returns completions formatted for nvim-cmp (with kind, detail, documentation)

## How It Works

The plugin spawns a Pi agent process in RPC mode (`pi --mode rpc --no-session`). It communicates with the agent via JSONL (JSON Lines) over stdin/stdout.

For each autocomplete request, the plugin gathers context from Neovim (current buffer, cursor position, workspace info) and sends a completion request to Pi.

For general prompting, the plugin sends the user's prompt along with the same context, plus recent buffers and visual selection if applicable.

Responses are displayed in floating windows with markdown syntax highlighting.

## Requirements

- Neovim >= 0.5.0
- [Pi coding agent](https://pi.dev) installed and available in your PATH
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (optional, for autocomplete)

## Health Check

Run `:checkhealth pi_neovim` to verify:

- Neovim version compatibility
- Pi binary installation and version
- nvim-cmp integration
- Plugin configuration
- Pi RPC mode enabled
- Agent process status

## Troubleshooting

### Pi agent fails to start

1. Ensure `pi` is in your PATH: run `:PiStart` and check for errors
2. Verify Pi RPC mode works: `pi --mode rpc --no-session` in terminal
3. Check `:PiStatus` for process status
4. Run `:checkhealth pi_neovim` for diagnostics

### Autocomplete not working

1. Ensure nvim-cmp is installed and configured
2. Check `:PiStatus` - agent must be running
3. Verify filetype is in `autocomplete.filetypes` (or empty for all)
4. Type at least `trigger_length` characters before completion triggers

### Commands not found

1. Ensure plugin is loaded: `:lua require("pi_neovim").setup({})`
2. Check for errors in `:messages`
3. Run `:checkhealth pi_neovim`

### Floating window issues

1. Ensure Neovim has floating window support (0.5.0+)
2. Check `ui.float` config for valid border/width/height values

## Development

This plugin was created as a demonstration of integrating Pi with Neovim. Feel free to extend it!

### Architecture

```
lua/pi_neovim/
├── init.lua          # Main entry point, config, setup
├── process.lua       # Process management, JSONL I/O
├── jsonl.lua         # JSONL parser for Pi RPC protocol
├── request.lua       # Request/response correlation, timeouts
├── context.lua       # Context gathering (buffer, workspace, selection)
├── cmp_source.lua    # nvim-cmp autocomplete source
├── commands.lua      # User commands (:PiPrompt, :PiStart, etc.)
├── ui.lua            # Floating window UI utilities
├── response.lua      # Streaming response handler
��── health.lua        # :checkhealth integration
```

## License

MIT
