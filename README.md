# Pi Neovim Plugin

This plugin integrates the [Pi coding agent](https://pi.dev) into Neovim to provide context-aware autocomplete and prompting capabilities via Pi's RPC mode.

## Features

- **Context-aware Autocomplete**: Uses Pi to provide code completions based on your current buffer, open buffers, and working directory.
- **Prompting**: Send arbitrary prompts to Pi from Neovim and see the results in a popup or split.
- **Process Management**: Automatically starts and stops the Pi agent process.
- **LazyVim Integration**: Works seamlessly with LazyVim.

## Installation

### Manual Installation (Neovim's built-in package system)

1. Clone the plugin into your Neovim package directory:

   ```bash
   git clone https://github.com/heavysudo/pi-neovim-plugin.git
   ```

2. The plugin will be automatically loaded on the next Neovim start.

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) (recommended for LazyVim users)

Add the following to your LazyVim configuration (e.g., in `lua/custom/plugins.lua`):

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
    -- Example: { "n", "<leader>pp", "<cmd>PiPrompt<cr>", desc = "Pi Prompt" },
  },
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

## Usage

### Autocomplete

Once the plugin is set up and nvim-cmp is installed, autocomplete will work automatically in supported filetypes. The plugin registers a source named "pi" with nvim-cmp.

### Prompting

Use the `:PiPrompt` command to send a prompt to Pi.

- `:PiPrompt Explain this function` - sends a prompt and shows the result in a floating window.
- In visual mode, select text and run `:PiPrompt` to ask about the selected text.

### Process Management

- `:PiStart` - manually start the Pi agent process (usually started automatically).
- `:PiStop` - stop the Pi agent process.
- `:PiRestart` - restart the Pi agent process.
- `:PiStatus` - show the status of the Pi agent.

## How It Works

The plugin spawns a Pi agent process in RPC mode (`pi --mode rpc --no-session`). It communicates with the agent via JSONL over stdin/stdout.

For each autocomplete request, the plugin gathers context from Neovim (current buffer, cursor position, open buffers, working directory) and sends a prompt to Pi asking for a code completion.

For general prompting, the plugin sends the user's prompt along with the same context.

## Requirements

- Neovim >= 0.5.0
- [Pi coding agent](https://pi.dev) installed and available in your PATH
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (optional, for autocomplete)

## Development

This plugin was created as a demonstration of integrating Pi with Neovim. Feel free to extend it!

## License

MIT
