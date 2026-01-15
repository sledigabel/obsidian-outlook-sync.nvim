-- Event renderer module
-- Converts calendar events to markdown format

local M = {}

-- render_event converts a single event to markdown lines
-- @param event table: CalendarEvent from CLI output (may have notes and deleted flag)
-- @return table: array of markdown line strings
function M.render_event(event)
	local lines = {}

	-- Add EVENT_ID marker (for Phase 4 merging)
	if event.id then
		table.insert(lines, string.format('<!-- EVENT_ID: %s -->', event.id))
	end

	-- Format event header
	local header
	local deleted_marker = event.deleted and ' [deleted]' or ''

	if event.isAllDay then
		-- All-day event
		local subject = event.subject ~= '' and event.subject or '(Untitled Event)'
		header = string.format('## All Day - %s%s', subject, deleted_marker)
	else
		-- Timed event - parse times and format
		local start_time = M._format_time(event.start)
		local end_time = M._format_time(event['end'])
		local subject = event.subject ~= '' and event.subject or '(Untitled Event)'
		header = string.format('## %s-%s %s%s', start_time, end_time, subject, deleted_marker)
	end

	table.insert(lines, header)

	-- Add Agenda section only if body content exists
	if event.body and event.body ~= '' then
		table.insert(lines, '')
		table.insert(lines, '### Agenda')
		table.insert(lines, '- <auto> ' .. event.body)
	end

	-- Add combined Attendees section (organizer + invitees in single line)
	table.insert(lines, '')
	table.insert(lines, '### Attendees')

	local attendee_names = {}

	-- Get organizer email for deduplication
	local org_email = event.organizer and event.organizer.email or ''

	-- Start with organizer marked as (O)
	if event.organizer then
		local org_display = event.organizer.name ~= '' and event.organizer.name or event.organizer.email
		if org_display ~= '' then
			table.insert(attendee_names, org_display .. ' (O)')
		end
	end

	-- Add invitees (up to 5), filtering out locations and organizer
	if event.attendees and #event.attendees > 0 then
		local max_display = 5
		local displayed = 0
		local total_filtered = 0

		for _, attendee in ipairs(event.attendees) do
			local name_display = attendee.name ~= '' and attendee.name or attendee.email

			-- Filter out locations (names starting with 3+ capital letters like "NYC", "LON")
			local is_location = name_display:match('^[A-Z][A-Z][A-Z]')

			-- Filter out organizer (deduplicate by email)
			local is_organizer = attendee.email == org_email

			if not is_location and not is_organizer then
				total_filtered = total_filtered + 1
				if displayed < max_display then
					table.insert(attendee_names, name_display)
					displayed = displayed + 1
				end
			end
		end

		-- Add truncation summary if more than 5 (after filtering)
		if total_filtered > max_display then
			local remaining = total_filtered - max_display
			table.insert(attendee_names, string.format('…and %d more', remaining))
		end
	end

	-- Output as single line
	if #attendee_names > 0 then
		table.insert(lines, table.concat(attendee_names, ', '))
	end

	-- Add notes pocket (preserved from old or scaffold for new)
	table.insert(lines, '')
	table.insert(lines, '### Notes')
	table.insert(lines, '<!-- NOTES_START -->')
	if event.notes then
		-- Preserve existing notes verbatim (FR-020)
		for _, note_line in ipairs(event.notes) do
			table.insert(lines, note_line)
		end
	else
		-- Scaffold for new events (FR-022)
		table.insert(lines, '')
	end
	table.insert(lines, '<!-- NOTES_END -->')

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
