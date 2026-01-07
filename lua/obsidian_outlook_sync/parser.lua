-- Buffer parser module
-- Finds and extracts managed regions from markdown buffers

local M = {}

-- Marker constants
M.AGENDA_START = '<!-- AGENDA_START -->'
M.AGENDA_END = '<!-- AGENDA_END -->'
M.EVENT_ID_PREFIX = '<!-- EVENT_ID: '
M.NOTES_START = '<!-- NOTES_START -->'
M.NOTES_END = '<!-- NOTES_END -->'

-- find_managed_region searches for AGENDA_START and AGENDA_END markers
-- @param lines table: array of line strings
-- @return start_line number|nil: 1-indexed line number of AGENDA_START
-- @return end_line number|nil: 1-indexed line number of AGENDA_END
function M.find_managed_region(lines)
	local start_line = nil
	local end_line = nil

	for i, line in ipairs(lines) do
		if not start_line and line:find(M.AGENDA_START, 1, true) then
			start_line = i
		elseif start_line and line:find(M.AGENDA_END, 1, true) then
			end_line = i
			break  -- Only find first pair
		end
	end

	-- Both markers must be present
	if start_line and end_line then
		return start_line, end_line
	else
		return nil, nil
	end
end

-- replace_managed_region atomically replaces content between markers
-- @param bufnr number: buffer number (0 for current buffer)
-- @param start_line number: 1-indexed line number of AGENDA_START
-- @param end_line number: 1-indexed line number of AGENDA_END
-- @param new_lines table: array of new line strings (without markers)
-- @return boolean: true if successful
function M.replace_managed_region(bufnr, start_line, end_line, new_lines)
	bufnr = bufnr or 0

	-- Build replacement lines including markers
	local replacement = {M.AGENDA_START}
	for _, line in ipairs(new_lines) do
		table.insert(replacement, line)
	end
	table.insert(replacement, M.AGENDA_END)

	-- nvim_buf_set_lines is 0-indexed and end is exclusive
	-- start_line and end_line are 1-indexed
	local start_idx = start_line - 1
	local end_idx = end_line

	-- Replace lines atomically
	vim.api.nvim_buf_set_lines(bufnr, start_idx, end_idx, false, replacement)

	return true
end

-- extract_event_id extracts event ID from EVENT_ID marker
-- @param line string: line containing EVENT_ID marker
-- @return string|nil: event ID or nil if not found
function M.extract_event_id(line)
	local prefix_start = line:find(M.EVENT_ID_PREFIX, 1, true)
	if not prefix_start then
		return nil
	end

	local id_start = prefix_start + #M.EVENT_ID_PREFIX
	local id_end = line:find(' -->', id_start, true)
	if not id_end then
		return nil
	end

	return line:sub(id_start, id_end - 1)
end

-- extract_event_with_notes extracts a single event with its notes pocket
-- @param lines table: array of all lines
-- @param start_idx number: 1-indexed start of event block
-- @param end_idx number: 1-indexed end of event block
-- @return table: {id=string, notes=table|nil, start_line=number, end_line=number}
function M.extract_event_with_notes(lines, start_idx, end_idx)
	local event = {
		start_line = start_idx,
		end_line = end_idx,
		id = nil,
		notes = nil
	}

	local notes_start = nil
	local notes_end = nil

	for i = start_idx, end_idx do
		local line = lines[i]

		-- Extract EVENT_ID
		if not event.id then
			event.id = M.extract_event_id(line)
		end

		-- Find notes pocket boundaries
		if line:find(M.NOTES_START, 1, true) then
			notes_start = i
		elseif line:find(M.NOTES_END, 1, true) then
			notes_end = i
			break
		end
	end

	-- Extract notes content if pocket exists
	if notes_start and notes_end then
		event.notes = {}
		for i = notes_start + 1, notes_end - 1 do
			table.insert(event.notes, lines[i])
		end
	end

	return event
end

-- parse_managed_region_events parses all events from managed region
-- @param lines table: array of all lines
-- @param start_line number: 1-indexed AGENDA_START line
-- @param end_line number: 1-indexed AGENDA_END line
-- @return table: array of event objects
function M.parse_managed_region_events(lines, start_line, end_line)
	local events = {}
	local current_event_start = nil

	for i = start_line + 1, end_line - 1 do
		local line = lines[i]

		-- Check if this line starts a new event
		if line:find(M.EVENT_ID_PREFIX, 1, true) then
			-- Save previous event if exists
			if current_event_start then
				local event = M.extract_event_with_notes(lines, current_event_start, i - 1)
				table.insert(events, event)
			end

			-- Start new event
			current_event_start = i
		end
	end

	-- Save last event
	if current_event_start then
		local event = M.extract_event_with_notes(lines, current_event_start, end_line - 1)
		table.insert(events, event)
	end

	return events
end

return M
