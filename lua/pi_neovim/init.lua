-- Pi Neovim Plugin
-- Main plugin module

local pi_neovim = {}

-- Default configuration
pi_neovim.default_config = {
	-- Pi command and arguments
	pi_cmd = { "pi", "--mode", "rpc", "--no-session" },
	-- Optional: model, thinking level, etc. can be added to the cmd array
	-- Example: { "pi", "--mode", "rpc", "--no-session", "--model", "claude-3-opus-20240229" },
	-- Context gathering options
	context = {
		-- How many lines around the cursor to send for autocomplete? (0 for whole buffer)
		lines_around_cursor = 0,
		-- Maximum buffer size to send (in bytes), 0 for no limit
		max_buffer_size = 0,
		-- Send entire buffer or just around cursor? If lines_around_cursor > 0, we send that many lines around.
		-- If lines_around_cursor == 0 and max_buffer_size == 0, we send the whole buffer.
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
}

pi_neovim.config = {}

-- Modules
local process = require("pi_neovim.process")
local context = require("pi_neovim.context")
local cmp_source = require("pi_neovim.cmp_source")
local commands = require("pi_neovim.commands")

-- Initialize the plugin
function pi_neovim.setup(user_config)
	-- Merge user config with default
	pi_neovim.config = vim.tbl_deep_extend("force", pi_neovim.default_config, user_config or {})

	-- Set up process callbacks
	process.set_on_stdout(function(chunk)
		-- TODO: handle stdout chunks (JSONL events)
		-- For now, we just print to Neovim's messages? Or we can log.
		-- We'll implement a proper event parser later.
	end)
	process.set_on_stderr(function(chunk)
		vim.notify("Pi stderr: " .. chunk, vim.log.levels.WARN)
	end)
	process.set_on_exit(function(code)
		if code ~= 0 then
			vim.notify("Pi agent exited with code: " .. code, vim.log.levels.ERROR)
		else
			vim.notify("Pi agent exited normally", vim.log.levels.INFO)
		end
	end)

	-- Start the Pi agent process
	local started = process.start({ cmd = pi_neovim.config.pi_cmd })
	if not started then
		vim.notify("Failed to start Pi agent", vim.log.levels.ERROR)
	end

	-- Set up nvim-cmp source if autocomplete is enabled
	if pi_neovim.config.autocomplete.enabled then
		require("cmp").register_source("pi", cmp_source.new())
		-- TODO: Set up autocompletion triggers (filetypes, trigger characters, etc.)
	end

	-- Set up user commands
	commands.setup()

	vim.notify("Pi Neovim plugin initialized", vim.log.levels.INFO)
end

-- Expose modules for external use (optional)
pi_neovim.process = process
pi_neovim.context = context
pi_neovim.cmp_source = cmp_source
pi_neovim.commands = commands

return pi_neovim

