-- Event merger module
-- Merges old and new events, preserving notes and handling deletions

local M = {}

-- is_meaningful_notes determines if notes contain user content
-- Per FR-025: meaningful if at least one line that is not blank, not a section header, not scaffold, and not starting with `- <auto>`
-- @param notes table|nil: array of note lines
-- @return boolean: true if notes contain meaningful content
function M.is_meaningful_notes(notes)
	if not notes or #notes == 0 then
		return false
	end

	for _, line in ipairs(notes) do
		-- Trim whitespace
		local trimmed = line:match('^%s*(.-)%s*$')

		-- Check if line is meaningful
		if trimmed ~= '' and
			not trimmed:match('^###') and  -- Not a section header
			not trimmed:match('^%- <auto>') then  -- Not scaffold/auto content
			return true
		end
	end

	return false
end

-- should_include_event determines if an event should be included in the output
-- @param event table: event to check
-- @return boolean: true if event should be included
local function should_include_event(event)
	-- Always include deleted events with meaningful notes
	if event.deleted and M.is_meaningful_notes(event.notes) then
		return true
	end

	-- Include all events now - user can decide what they want to see
	-- Previous filter removed single-person meetings, but this was too aggressive
	-- and removed legitimate overlapping personal events
	return true
end

-- merge_events merges old and new event lists, preserving notes
-- @param old_events table: array of events from previous buffer state
-- @param new_events table: array of events from CLI output
-- @return table: merged array of events with preserved notes and deletion markers
function M.merge_events(old_events, new_events)
	-- Build lookup map of old events by ID
	local old_by_id = {}
	for _, event in ipairs(old_events) do
		if event.id then
			old_by_id[event.id] = event
		end
	end

	-- Build lookup map of new events by ID
	local new_by_id = {}
	for _, event in ipairs(new_events) do
		if event.id then
			new_by_id[event.id] = event
		end
	end

	local merged = {}

	-- Process new events (including updates to existing)
	for _, new_event in ipairs(new_events) do
		local event_id = new_event.id

		if old_by_id[event_id] then
			-- Event exists in old - preserve notes
			local old_event = old_by_id[event_id]
			new_event.notes = old_event.notes
		end

		-- Only include if it passes the filter
		if should_include_event(new_event) then
			table.insert(merged, new_event)
		end
	end

	-- Process deleted events (in old but not in new)
	for _, old_event in ipairs(old_events) do
		local event_id = old_event.id

		if not new_by_id[event_id] then
			-- Event was deleted
			if M.is_meaningful_notes(old_event.notes) then
				-- Retain with [deleted] marker (FR-023)
				old_event.deleted = true
				-- Only include if it passes the filter
				if should_include_event(old_event) then
					table.insert(merged, old_event)
				end
			end
			-- Otherwise remove entirely (FR-024)
		end
	end

	return merged
end

return M
