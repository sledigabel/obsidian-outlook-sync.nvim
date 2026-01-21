-- Navigation module
-- Handles finding current/upcoming meetings and cursor positioning

local M = {}

-- compare_time compares a time against a range
-- @param hour number: current hour (0-23)
-- @param min number: current minute (0-59)
-- @param start_hour number: range start hour
-- @param start_min number: range start minute
-- @param end_hour number: range end hour
-- @param end_min number: range end minute
-- @return string: 'current' if in range, 'past' if before range, 'future' if after range
function M.compare_time(hour, min, start_hour, start_min, end_hour, end_min)
	local current_minutes = hour * 60 + min
	local start_minutes = start_hour * 60 + start_min
	local end_minutes = end_hour * 60 + end_min
	
	if current_minutes >= start_minutes and current_minutes < end_minutes then
		return 'current'
	elseif current_minutes < start_minutes then
		return 'future'
	else
		return 'past'
	end
end

-- find_current_meetings finds all meetings happening at the current time
-- @param events table: array of events with .times and .notes_line fields
-- @param current_time table: {hour=number, min=number}
-- @return table: array of matching events
function M.find_current_meetings(events, current_time)
	local matches = {}
	
	for _, event in ipairs(events) do
		-- Skip events without times (all-day events)
		if event.times then
			local status = M.compare_time(
				current_time.hour,
				current_time.min,
				event.times.start_hour,
				event.times.start_min,
				event.times.end_hour,
				event.times.end_min
			)
			
			if status == 'current' then
				table.insert(matches, event)
			end
		end
	end
	
	return matches
end

-- find_next_meeting finds the next upcoming meeting after current time
-- @param events table: array of events with .times field
-- @param current_time table: {hour=number, min=number}
-- @return table|nil: next event or nil if none
function M.find_next_meeting(events, current_time)
	local next_event = nil
	local next_minutes = math.huge
	
	for _, event in ipairs(events) do
		-- Skip events without times (all-day events)
		if event.times then
			local status = M.compare_time(
				current_time.hour,
				current_time.min,
				event.times.start_hour,
				event.times.start_min,
				event.times.end_hour,
				event.times.end_min
			)
			
			if status == 'future' then
				local start_minutes = event.times.start_hour * 60 + event.times.start_min
				if start_minutes < next_minutes then
					next_minutes = start_minutes
					next_event = event
				end
			end
		end
	end
	
	return next_event
end

-- jump_to_notes positions cursor on the first line inside the notes pocket
-- @param event table: event with .notes_line field
-- @return boolean: true if successful
function M.jump_to_notes(event)
	if not event.notes_line then
		return false
	end
	
	-- Position cursor on line after NOTES_START marker (0-indexed for API, but notes_line is 1-indexed)
	-- So we want line notes_line + 1 in 1-indexed terms, which is notes_line in 0-indexed
	vim.api.nvim_win_set_cursor(0, {event.notes_line + 1, 0})
	
	return true
end

-- show_meeting_picker displays a selection UI for overlapping meetings
-- @param events table: array of events
-- @param callback function: called with selected event
function M.show_meeting_picker(events, callback)
	-- Build display items
	local items = {}
	for _, event in ipairs(events) do
		local time_str = ''
		if event.times then
			time_str = string.format(
				'%02d:%02d-%02d:%02d',
				event.times.start_hour,
				event.times.start_min,
				event.times.end_hour,
				event.times.end_min
			)
		else
			time_str = 'All Day'
		end
		
		table.insert(items, {
			display = string.format('%s %s', time_str, event.subject or '(Untitled)'),
			event = event
		})
	end
	
	-- Show picker
	vim.ui.select(items, {
		prompt = 'Select meeting:',
		format_item = function(item)
			return item.display
		end
	}, function(choice)
		if choice then
			callback(choice.event)
		end
	end)
end

-- parse_subject_from_header extracts subject from markdown header
-- @param line string: header line (e.g., "## 09:00-10:00 Team Meeting")
-- @return string: subject or empty string
function M.parse_subject_from_header(line)
	-- For timed events: ## HH:MM-HH:MM Subject
	local subject = line:match('^## %d%d:%d%d%-%d%d:%d%d%s+(.+)$')
	if subject then
		-- Remove [deleted] marker if present
		subject = subject:gsub('%s*%[deleted%]%s*$', '')
		return subject
	end
	
	-- For all-day events: ## All Day - Subject
	subject = line:match('^## All Day %- (.+)$')
	if subject then
		subject = subject:gsub('%s*%[deleted%]%s*$', '')
		return subject
	end
	
	return ''
end

return M
