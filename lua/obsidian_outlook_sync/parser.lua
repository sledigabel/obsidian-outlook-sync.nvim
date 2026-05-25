-- Buffer parser module
-- Finds and extracts managed regions from markdown buffers

local M = {}

-- Marker constants
M.AGENDA_START = '<!-- AGENDA_START -->'
M.AGENDA_END = '<!-- AGENDA_END -->'
M.EVENT_ID_PREFIX = '<!-- EVENT_ID: '
M.NOTES_START = '<!-- NOTES_START -->'
M.NOTES_END = '<!-- NOTES_END -->'
M.TIMESTAMP_PREFIX     = '<!-- TIMESTAMP: '
M.TIMESTAMP_END_PREFIX = '<!-- TIMESTAMP_END: '

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

-- extract_timestamp extracts UTC Unix start timestamp from TIMESTAMP marker line
-- @param line string
-- @return number|nil
function M.extract_timestamp(line)
	local prefix_start = line:find(M.TIMESTAMP_PREFIX, 1, true)
	if not prefix_start then return nil end
	local val_start = prefix_start + #M.TIMESTAMP_PREFIX
	local val_end   = line:find(' -->', val_start, true)
	if not val_end then return nil end
	return tonumber(line:sub(val_start, val_end - 1))
end

-- extract_timestamp_end extracts UTC Unix end timestamp from TIMESTAMP_END marker line
-- @param line string
-- @return number|nil
function M.extract_timestamp_end(line)
	local prefix_start = line:find(M.TIMESTAMP_END_PREFIX, 1, true)
	if not prefix_start then return nil end
	local val_start = prefix_start + #M.TIMESTAMP_END_PREFIX
	local val_end   = line:find(' -->', val_start, true)
	if not val_end then return nil end
	return tonumber(line:sub(val_start, val_end - 1))
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
		notes = nil,
		startUnix = nil,
		endUnix = nil,
	}

	local notes_start = nil
	local notes_end = nil

	for i = start_idx, end_idx do
		local line = lines[i]

		-- Extract EVENT_ID
		if not event.id then
			event.id = M.extract_event_id(line)
		end

		-- Extract timestamps
		if not event.startUnix then
			event.startUnix = M.extract_timestamp(line)
		end
		if not event.endUnix then
			event.endUnix = M.extract_timestamp_end(line)
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

-- parse_event_times extracts start and end times from event header
-- @param lines table: array of all lines
-- @param start_idx number: 1-indexed start of event block
-- @param end_idx number: 1-indexed end of event block
-- @return table|nil: {start_hour=number, start_min=number, end_hour=number, end_min=number} or nil for all-day/unparseable
function M.parse_event_times(lines, start_idx, end_idx)
	-- Look for header line with time format: ## HH:MM-HH:MM Subject
	for i = start_idx, end_idx do
		local line = lines[i]
		-- Match pattern: ## HH:MM-HH:MM
		local start_hour, start_min, end_hour, end_min = line:match('^## (%d%d):(%d%d)%-(%d%d):(%d%d)')
		if start_hour then
			return {
				start_hour = tonumber(start_hour),
				start_min = tonumber(start_min),
				end_hour = tonumber(end_hour),
				end_min = tonumber(end_min)
			}
		end
	end
	return nil
end

-- find_notes_line finds the line number of NOTES_START marker in an event
-- @param lines table: array of all lines
-- @param start_idx number: 1-indexed start of event block
-- @param end_idx number: 1-indexed end of event block
-- @return number|nil: 1-indexed line number of NOTES_START, or nil if not found
function M.find_notes_line(lines, start_idx, end_idx)
	for i = start_idx, end_idx do
		local line = lines[i]
		if line:find(M.NOTES_START, 1, true) then
			return i
		end
	end
	return nil
end

-- extract_title extracts the meeting title from the ## header line.
-- Handles timed events (## HH:MM-HH:MM Subject), all-day events
-- (## All Day - Subject), and strips trailing [deleted] markers.
-- @param lines table: array of all lines
-- @param start_idx number: 1-indexed start of event block
-- @param end_idx number: 1-indexed end of event block
-- @return string|nil: meeting title, or nil if no ## header found
local function extract_title(lines, start_idx, end_idx)
  for i = start_idx, end_idx do
    local line = lines[i]
    if line:match('^## ') then
      local title

      -- Timed event: ## HH:MM-HH:MM Subject
      title = line:match('^## %d%d:%d%d%-%d%d:%d%d (.+)$')

      -- All-day event: ## All Day - Subject
      if not title then
        title = line:match('^## All Day %- (.+)$')
      end

      -- Fallback: strip ## prefix
      if not title then
        title = line:sub(4)
      end

      -- Strip trailing [deleted]
      if title then
        title = title:gsub('%s*%[deleted%]%s*$', '')
      end

      return title ~= '' and title or nil
    end
  end
  return nil
end

-- extract_attendees extracts attendee names from the ### Attendees section.
-- Returns an array of trimmed name strings (including "...and N more" lines).
-- Returns an empty table if the section is absent.
-- @param lines table: array of all lines
-- @param start_idx number: 1-indexed start of event block
-- @param end_idx number: 1-indexed end of event block
-- @return table: array of attendee name strings
local function extract_attendees(lines, start_idx, end_idx)
  local attendees = {}
  local in_section = false

  for i = start_idx, end_idx do
    local line = lines[i]

    if line:match('^### Attendees') then
      in_section = true
    elseif in_section then
      -- Stop at next ### section
      if line:match('^### ') then
        break
      end
      -- Collect non-empty lines
      local trimmed = line:match('^%s*(.-)%s*$')
      if trimmed and trimmed ~= '' then
        table.insert(attendees, trimmed)
      end
    end
  end

  return attendees
end

-- get_event_at_cursor returns meeting properties for the event at the cursor.
-- Returns nil if the cursor is not inside any event block.
-- @param bufnr number|nil: buffer number (defaults to 0, current buffer)
-- @return table|nil: {id, title, startUnix, endUnix, isAllDay, attendees}
function M.get_event_at_cursor(bufnr)
  bufnr = bufnr or 0

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]  -- 1-indexed

  local start_line, end_line = M.find_managed_region(lines)
  if not start_line then
    return nil
  end

  -- Cursor must be strictly inside the region (not on the marker lines)
  if cursor_row <= start_line or cursor_row >= end_line then
    return nil
  end

  local events = M.parse_managed_region_events(lines, start_line, end_line)

  for _, event in ipairs(events) do
    -- Trim trailing blank lines from event boundary for cursor hit-testing
    local content_end = event.end_line
    while content_end > event.start_line and lines[content_end]:match('^%s*$') do
      content_end = content_end - 1
    end
    if cursor_row >= event.start_line and cursor_row <= content_end then
      return {
        id        = event.id,
        title     = extract_title(lines, event.start_line, event.end_line),
        startUnix = event.startUnix,
        endUnix   = event.endUnix,
        isAllDay  = event.startUnix == nil,
        attendees = extract_attendees(lines, event.start_line, event.end_line),
      }
    end
  end

  return nil
end

return M
