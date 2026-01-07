-- Obsidian Outlook Sync Plugin
-- Main initialization and command registration

local M = {}

-- Plugin state
M.config = {
	cli_path = 'outlook-md',  -- Path to outlook-md CLI binary
	timezone = 'Local',        -- Default timezone
}

-- Setup function called by users in their init.lua
function M.setup(opts)
	opts = opts or {}

	-- Merge user config with defaults
	M.config = vim.tbl_extend('force', M.config, opts)

	-- Register commands
	vim.api.nvim_create_user_command('OutlookAgendaToday', function()
		require('obsidian_outlook_sync.commands').agenda_today()
	end, {
		desc = 'Sync today\'s Outlook calendar events into managed region'
	})

	-- TODO: Add more commands in future phases (US3-US6)
	-- vim.api.nvim_create_user_command('OutlookAgendaTomorrow', ...)
	-- vim.api.nvim_create_user_command('OutlookAgendaWeek', ...)
end

return M
