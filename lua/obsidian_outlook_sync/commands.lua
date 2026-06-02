-- Command handlers
-- Orchestrates parser, CLI, merger, renderer, and buffer replacement

local parser = require('obsidian_outlook_sync.parser')
local cli = require('obsidian_outlook_sync.cli')
local merger = require('obsidian_outlook_sync.merger')
local renderer = require('obsidian_outlook_sync.renderer')
local navigation = require('obsidian_outlook_sync.navigation')

local M = {}

-- fetch_and_sync is a generic function to fetch and sync calendar events
local function fetch_and_sync(command, description)
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

	-- Parse existing events from managed region
	local old_events = parser.parse_managed_region_events(lines, start_line, end_line)

	-- Invoke CLI with callback
	cli.invoke_cli(command, {
		cli_path = config.cli_path,
		timezone = config.timezone,
		format = 'json',
	}, function(cli_output, err)
		if err then
			vim.notify('Failed to fetch calendar events: ' .. err, vim.log.levels.ERROR)
			return
		end

		-- Merge old and new events, preserving notes
		local merged_events = merger.merge_events(old_events, cli_output.events)

		-- Render events to markdown
		local event_lines = renderer.render_events(merged_events)

		-- Replace managed region
		local new_lines = {}

		-- Lines before region
		for i = 1, start_line do
			table.insert(new_lines, lines[i])
		end

		-- New event lines
		for _, line in ipairs(event_lines) do
			table.insert(new_lines, line)
		end

		-- Lines after region
		for i = end_line, #lines do
			table.insert(new_lines, lines[i])
		end

		-- Update buffer
		local success = pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, new_lines)
		if success then
			vim.notify('Synced ' .. #merged_events .. ' events for ' .. description, vim.log.levels.INFO)
		else
			vim.notify('Failed to update buffer', vim.log.levels.ERROR)
		end
	end)
end

-- agenda_today fetches and displays today's calendar events
function M.agenda_today()
	fetch_and_sync('today', "today's")
end

-- agenda_tomorrow fetches and displays tomorrow's calendar events
function M.agenda_tomorrow()
	fetch_and_sync('tomorrow', "tomorrow's")
end

-- agenda_week fetches and displays this week's calendar events
function M.agenda_week()
	fetch_and_sync('week', "this week's")
end

-- jump_to_current_notes positions cursor on notes section of current or next meeting
function M.jump_to_current_notes()
	-- Get current buffer lines
	local bufnr = 0  -- Current buffer
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	
	-- Find managed region
	local start_line, end_line = parser.find_managed_region(lines)
	if not start_line or not end_line then
		vim.notify('Could not find AGENDA_START and AGENDA_END markers in buffer', vim.log.levels.ERROR)
		return
	end
	
	-- Parse existing events from managed region
	local parsed_events = parser.parse_managed_region_events(lines, start_line, end_line)
	
	if not parsed_events or #parsed_events == 0 then
		vim.notify('No meetings in agenda', vim.log.levels.INFO)
		return
	end
	
	-- Enrich events with time information and notes line numbers
	local events = {}
	for _, event in ipairs(parsed_events) do
		local times = parser.parse_event_times(lines, event.start_line, event.end_line)
		local notes_line = parser.find_notes_line(lines, event.start_line, event.end_line)
		
		-- Extract subject from header
		local subject = ''
		for i = event.start_line, event.end_line do
			if lines[i]:match('^##%s+') then
				subject = navigation.parse_subject_from_header(lines[i])
				break
			end
		end
		
		table.insert(events, {
			id = event.id,
			times = times,
			notes_line = notes_line,
			subject = subject,
			start_line = event.start_line,
			end_line = event.end_line
		})
	end
	
	-- Get current time
	local now = os.date('*t')
	local current_time = {hour = now.hour, min = now.min}
	
	-- Find current meetings
	local current_meetings = navigation.find_current_meetings(events, current_time)
	
	if #current_meetings > 1 then
		-- Multiple overlapping meetings - show picker
		navigation.show_meeting_picker(current_meetings, function(selected_event)
			if navigation.jump_to_notes(selected_event) then
				vim.notify('Jumped to notes for current meeting', vim.log.levels.INFO)
			else
				vim.notify('Could not find notes section', vim.log.levels.ERROR)
			end
		end)
		return
	elseif #current_meetings == 1 then
		-- Single current meeting - jump directly
		if navigation.jump_to_notes(current_meetings[1]) then
			vim.notify('Jumped to notes for current meeting', vim.log.levels.INFO)
		else
			vim.notify('Could not find notes section', vim.log.levels.ERROR)
		end
		return
	end
	
	-- No current meeting - find next upcoming
	local next_meeting = navigation.find_next_meeting(events, current_time)
	
	if next_meeting then
		if navigation.jump_to_notes(next_meeting) then
			vim.notify('No current meeting. Jumped to notes for next upcoming meeting', vim.log.levels.INFO)
		else
			vim.notify('Could not find notes section', vim.log.levels.ERROR)
		end
	else
		vim.notify('No current or upcoming meetings', vim.log.levels.INFO)
	end
end

-- event_at_cursor prints the meeting properties for the event under the cursor
function M.event_at_cursor()
	local event = parser.get_event_at_cursor(0)
	if not event then
		vim.notify('Cursor is not inside a meeting block', vim.log.levels.WARN)
		return
	end
	vim.notify(vim.fn.json_encode(event), vim.log.levels.INFO)
end

-- jump_to_next_meeting positions cursor on notes section of the next meeting after cursor
function M.jump_to_next_meeting()
	-- Get current buffer lines
	local bufnr = 0  -- Current buffer
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	
	-- Find managed region
	local start_line, end_line = parser.find_managed_region(lines)
	if not start_line or not end_line then
		return
	end
	
	-- Parse existing events from managed region
	local parsed_events = parser.parse_managed_region_events(lines, start_line, end_line)
	
	if not parsed_events or #parsed_events == 0 then
		return
	end
	
	-- Enrich events with time information and notes line numbers
	local events = {}
	for _, event in ipairs(parsed_events) do
		local times = parser.parse_event_times(lines, event.start_line, event.end_line)
		local notes_line = parser.find_notes_line(lines, event.start_line, event.end_line)
		
		-- Extract subject from header
		local subject = ''
		for i = event.start_line, event.end_line do
			if lines[i]:match('^##%s+') then
				subject = navigation.parse_subject_from_header(lines[i])
				break
			end
		end
		
		table.insert(events, {
			id = event.id,
			times = times,
			notes_line = notes_line,
			subject = subject,
			start_line = event.start_line,
			end_line = event.end_line
		})
	end
	
	-- Get current cursor line
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	
	-- Find next meeting
	local next_meeting = navigation.find_next_meeting_from_cursor(events, cursor_line)
	
	if next_meeting then
		navigation.jump_to_notes(next_meeting)
	end
end

-- jump_to_previous_meeting positions cursor on notes section of the previous meeting before cursor
function M.jump_to_previous_meeting()
	-- Get current buffer lines
	local bufnr = 0  -- Current buffer
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	
	-- Find managed region
	local start_line, end_line = parser.find_managed_region(lines)
	if not start_line or not end_line then
		return
	end
	
	-- Parse existing events from managed region
	local parsed_events = parser.parse_managed_region_events(lines, start_line, end_line)
	
	if not parsed_events or #parsed_events == 0 then
		return
	end
	
	-- Enrich events with time information and notes line numbers
	local events = {}
	for _, event in ipairs(parsed_events) do
		local times = parser.parse_event_times(lines, event.start_line, event.end_line)
		local notes_line = parser.find_notes_line(lines, event.start_line, event.end_line)
		
		-- Extract subject from header
		local subject = ''
		for i = event.start_line, event.end_line do
			if lines[i]:match('^##%s+') then
				subject = navigation.parse_subject_from_header(lines[i])
				break
			end
		end
		
		table.insert(events, {
			id = event.id,
			times = times,
			notes_line = notes_line,
			subject = subject,
			start_line = event.start_line,
			end_line = event.end_line
		})
	end
	
	-- Get current cursor line
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	
	-- Find previous meeting
	local prev_meeting = navigation.find_previous_meeting_from_cursor(events, cursor_line)
	
	if prev_meeting then
		navigation.jump_to_notes(prev_meeting)
	end
end

return M
