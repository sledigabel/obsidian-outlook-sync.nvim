-- Obsidian Outlook Sync Plugin
-- Main initialization and command registration

local M = {}

-- Plugin state
M.config = {
	cli_path = 'outlook-md',  -- Path to outlook-md CLI binary
	timezone = 'Local',        -- Default timezone
}

-- Resolve CLI path, checking plugin's bin/ directory if not found in PATH
local function resolve_cli_path(cli_path)
	-- If it's already an absolute path, use it as-is
	if cli_path:match('^/') then
		return cli_path
	end

	-- Try to find it in PATH first
	local result = vim.fn.exepath(cli_path)
	if result ~= '' then
		return result
	end

	-- Fallback: check plugin's bin/ directory
	local script_path = debug.getinfo(1, 'S').source:sub(2)
	local plugin_dir = vim.fn.fnamemodify(script_path, ':h:h:h')
	local local_cli = plugin_dir .. '/bin/' .. cli_path

	-- Check if it exists
	if vim.fn.executable(local_cli) == 1 then
		return local_cli
	end

	-- Return original path and let it fail with a clear error
	return cli_path
end

-- Setup function called by users in their init.lua
function M.setup(opts)
	opts = opts or {}

	-- Merge user config with defaults
	M.config = vim.tbl_extend('force', M.config, opts)

	-- Resolve CLI path
	M.config.cli_path = resolve_cli_path(M.config.cli_path)

	-- Register commands
	vim.api.nvim_create_user_command('OutlookAgendaToday', function()
		require('obsidian_outlook_sync.commands').agenda_today()
	end, {
		desc = 'Sync today\'s Outlook calendar events into managed region'
	})

	vim.api.nvim_create_user_command('OutlookAgendaTomorrow', function()
		require('obsidian_outlook_sync.commands').agenda_tomorrow()
	end, {
		desc = 'Sync tomorrow\'s Outlook calendar events into managed region'
	})

	vim.api.nvim_create_user_command('OutlookAgendaWeek', function()
		require('obsidian_outlook_sync.commands').agenda_week()
	end, {
		desc = 'Sync this week\'s Outlook calendar events into managed region'
	})
end

return M
