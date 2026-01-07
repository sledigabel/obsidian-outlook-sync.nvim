-- Command handlers
-- Orchestrates parser, CLI, renderer, and buffer replacement

local parser = require('obsidian_outlook_sync.parser')
local cli = require('obsidian_outlook_sync.cli')
local renderer = require('obsidian_outlook_sync.renderer')

local M = {}

-- agenda_today fetches and displays today's calendar events
function M.agenda_today()
	-- Get plugin config
	local config = require('obsidian_outlook_sync').config

	-- Get current buffer lines
	local bufnr = 0  -- Current buffer
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- Find managed region
	local start_line, end_line = parser.find_managed_region(lines)
	if not start_line or not end_line then
		vim.notify('Could not find AGENDA_START and AGENDA_END markers in buffer', vim.log.levels.ERROR)
		return
	end

	-- Invoke CLI
	vim.notify('Fetching calendar events...', vim.log.levels.INFO)
	local cli_output, err = cli.invoke_cli('today', {
		cli_path = config.cli_path,
		timezone = config.timezone,
		format = 'json',
	})

	if err then
		vim.notify('Failed to fetch calendar events: ' .. err, vim.log.levels.ERROR)
		return
	end

	-- Render events to markdown
	local event_lines = renderer.render_events(cli_output.events)

	-- Replace managed region
	local success = parser.replace_managed_region(bufnr, start_line, end_line, event_lines)

	if success then
		vim.notify(string.format('Synced %d events', #cli_output.events), vim.log.levels.INFO)
	else
		vim.notify('Failed to update buffer', vim.log.levels.ERROR)
	end
end

return M
