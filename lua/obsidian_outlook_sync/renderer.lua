-- Event renderer module
-- Converts calendar events to markdown format

local M = {}

-- render_event converts a single event to markdown lines
-- @param event table: CalendarEvent from CLI output
-- @return table: array of markdown line strings
function M.render_event(event)
	local lines = {}

	-- Format event header
	local header
	if event.isAllDay then
		-- All-day event
		local subject = event.subject ~= '' and event.subject or '(Untitled Event)'
		header = string.format('## All Day - %s', subject)
	else
		-- Timed event - parse times and format
		local start_time = M._format_time(event.start)
		local end_time = M._format_time(event['end'])
		local subject = event.subject ~= '' and event.subject or '(Untitled Event)'
		header = string.format('## %s-%s %s', start_time, end_time, subject)
	end

	table.insert(lines, header)

	-- Add location if present
	if event.location and event.location ~= '' then
		table.insert(lines, string.format('**Location:** %s', event.location))
	end

	-- Add organizer
	if event.organizer and event.organizer.name ~= '' then
		table.insert(lines, string.format('**Organizer:** %s', event.organizer.name))
	end

	-- Add attendees if present
	if event.attendees and #event.attendees > 0 then
		local attendee_names = {}
		for _, attendee in ipairs(event.attendees) do
			if attendee.name and attendee.name ~= '' then
				table.insert(attendee_names, attendee.name)
			end
		end
		if #attendee_names > 0 then
			table.insert(lines, string.format('**Attendees:** %s', table.concat(attendee_names, ', ')))
		end
	end

	-- Add blank line after event
	table.insert(lines, '')

	return lines
end

-- render_events converts multiple events to markdown lines
-- @param events table: array of CalendarEvent objects
-- @return table: array of markdown line strings
function M.render_events(events)
	local lines = {}

	if not events or #events == 0 then
		-- No events to render
		table.insert(lines, '*No events for this time period*')
		return lines
	end

	for _, event in ipairs(events) do
		local event_lines = M.render_event(event)
		for _, line in ipairs(event_lines) do
			table.insert(lines, line)
		end
	end

	return lines
end

-- _format_time formats an ISO 8601 datetime string to HH:MM format
-- @param datetime string: ISO 8601 datetime (e.g., "2026-01-07T09:00:00Z")
-- @return string: time in HH:MM format (e.g., "09:00")
function M._format_time(datetime)
	-- Parse ISO 8601 format: YYYY-MM-DDTHH:MM:SS
	local hour, min = datetime:match('T(%d%d):(%d%d):')
	if hour and min then
		return string.format('%s:%s', hour, min)
	end

	-- Fallback to showing full datetime if parsing fails
	return datetime
end

return M
