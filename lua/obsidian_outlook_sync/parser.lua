-- Buffer parser module
-- Finds and extracts managed regions from markdown buffers

local M = {}

-- Marker constants
M.AGENDA_START = '<!-- AGENDA_START -->'
M.AGENDA_END = '<!-- AGENDA_END -->'

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

return M
