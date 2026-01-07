-- Command handlers
-- Orchestrates parser, CLI, merger, renderer, and buffer replacement

local parser = require('obsidian_outlook_sync.parser')
local cli = require('obsidian_outlook_sync.cli')
local merger = require('obsidian_outlook_sync.merger')
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

	-- Parse existing events from managed region (Phase 4)
	local old_events = parser.parse_managed_region_events(lines, start_line, end_line)

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

	-- Merge old and new events, preserving notes (Phase 4)
	local merged_events = merger.merge_events(old_events, cli_output.events)

	-- Render events to markdown
	local event_lines = renderer.render_events(merged_events)

	-- Replace managed region
	local success = parser.replace_managed_region(bufnr, start_line, end_line, event_lines)

	if success then
		local active_count = 0
		local deleted_count = 0
		for _, event in ipairs(merged_events) do
			if event.deleted then
				deleted_count = deleted_count + 1
			else
				active_count = active_count + 1
			end
		end

		local msg = string.format('Synced %d events', active_count)
		if deleted_count > 0 then
			msg = msg .. string.format(' (%d deleted events retained)', deleted_count)
		end
		vim.notify(msg, vim.log.levels.INFO)
	else
		vim.notify('Failed to update buffer', vim.log.levels.ERROR)
	end
end

return M
