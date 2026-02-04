-- CLI invocation module
-- Handles subprocess calls to outlook-md CLI

local M = {}

-- Show a floating window with authentication instructions
local function show_auth_window(stderr_output)
	-- Create a buffer for the floating window
	local buf = vim.api.nvim_create_buf(false, true)
	if not buf or buf == 0 then
		vim.notify('Failed to create authentication window buffer', vim.log.levels.ERROR)
		return
	end

	-- Split stderr output into lines and add helpful header
	local lines = vim.split(stderr_output, '\n', { plain = true })
	
	-- Add header with instructions
	local header = {
		'',
		'╔══════════════════════════════════════════════════════════╗',
		'║          OUTLOOK AUTHENTICATION REQUIRED                 ║',
		'╚══════════════════════════════════════════════════════════╝',
		'',
	}
	
	-- Combine header with stderr output
	local all_lines = {}
	for _, line in ipairs(header) do
		table.insert(all_lines, line)
	end
	for _, line in ipairs(lines) do
		table.insert(all_lines, line)
	end
	
	-- Add footer
	table.insert(all_lines, '')
	table.insert(all_lines, string.rep('─', 60))
	table.insert(all_lines, 'Press q or <Esc> to close this window')
	table.insert(all_lines, '')

	-- Set buffer content
	local ok, err = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, all_lines)
	if not ok then
		vim.notify('Failed to set authentication window content: ' .. tostring(err), vim.log.levels.ERROR)
		return
	end

	-- Calculate window size - make it wider to accommodate long lines
	local width = 100  -- Increased from 64 to prevent wrapping
	local height = math.min(#all_lines, 30) -- Increased max height to 30

	-- Get editor dimensions safely
	local uis = vim.api.nvim_list_uis()
	if not uis or #uis == 0 then
		vim.notify('No UI available to show authentication window', vim.log.levels.ERROR)
		return
	end
	
	local ui = uis[1]
	local win_width = ui.width
	local win_height = ui.height

	-- Adjust window width if screen is too narrow
	if width > win_width - 4 then
		width = win_width - 4
	end

	-- Calculate centered position
	local row = math.floor((win_height - height) / 2)
	local col = math.floor((win_width - width) / 2)

	-- Create floating window
	local win_opts = {
		relative = 'editor',
		width = width,
		height = height,
		row = row,
		col = col,
		style = 'minimal',
		border = 'rounded',
		title = ' Authentication Required ',
		title_pos = 'center',
		focusable = true,
	}
	
	local win_ok, win = pcall(vim.api.nvim_open_win, buf, true, win_opts)
	if not win_ok then
		vim.notify('Failed to create authentication window: ' .. tostring(win), vim.log.levels.ERROR)
		return
	end

	-- Set buffer options using vim.bo (newer API)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].bufhidden = 'wipe'
	
	-- Set window options to prevent wrapping
	vim.wo[win].wrap = false
	vim.wo[win].linebreak = false
	vim.wo[win].cursorline = true

	-- Add keybinding to close the window
	vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<CR>', { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<cmd>close<CR>', { noremap = true, silent = true })
end

-- invoke_cli executes the outlook-md CLI and returns parsed JSON output
-- @param command string: CLI command to run (e.g., "today")
-- @param opts table: options { cli_path, timezone, format }
-- @param callback function: Called with (result, error) when complete
function M.invoke_cli(command, opts, callback)
	opts = opts or {}
	local cli_path = opts.cli_path or 'outlook-md'
	local timezone = opts.timezone or 'Local'
	local format = opts.format or 'json'

	-- Build command arguments
	local cmd_str = string.format('%s %s --format %s --tz %s',
		vim.fn.shellescape(cli_path),
		vim.fn.shellescape(command),
		vim.fn.shellescape(format),
		vim.fn.shellescape(timezone)
	)

	local exit_code = nil
	local stderr_lines = {}
	local stdout_lines = {}
	local auth_window_shown = false
	local start_time = vim.loop.hrtime()

	vim.notify('Fetching calendar events...', vim.log.levels.INFO)

	-- Use jobstart for asynchronous execution
	local job_id = vim.fn.jobstart(cmd_str, {
		on_stdout = function(_, data, _)
			if data then
				for _, line in ipairs(data) do
					if line ~= '' then
						table.insert(stdout_lines, line)
					end
				end
			end
		end,
		on_stderr = function(_, data, _)
			if data then
				for _, line in ipairs(data) do
					if line ~= '' then
						table.insert(stderr_lines, line)
					end
				end
			end
		end,
		on_exit = function(_, code, _)
			exit_code = code
			
			-- Job completed
			local stdout_str = table.concat(stdout_lines, '\n')
			local stderr_str = table.concat(stderr_lines, '\n')

			-- Check for errors
			if code ~= 0 then
				local error_msg = stderr_str ~= '' and stderr_str or stdout_str
				callback(nil, string.format("outlook-md exited with code %d: %s", code, error_msg))
				return
			end

			-- Parse JSON output from stdout
			local json_start = stdout_str:find('{')
			if json_start then
				stdout_str = stdout_str:sub(json_start)
			end

			local ok, parsed = pcall(vim.json.decode, stdout_str)
			if not ok then
				callback(nil, string.format("Failed to parse CLI output as JSON: %s\nStdout: %s\nStderr: %s", 
					parsed, stdout_str, stderr_str))
				return
			end

			-- Validate schema version
			if parsed.version ~= 1 then
				callback(nil, string.format("Unsupported CLI output version: %d (expected 1)", parsed.version))
				return
			end

			callback(parsed, nil)
		end,
		stdout_buffered = false,
		stderr_buffered = false,
	})

	-- Check if job started successfully
	if job_id <= 0 then
		callback(nil, string.format("Failed to start outlook-md process (job_id: %d)", job_id))
		return
	end

	-- Set up a timer to show auth window after 5 seconds if job is still running
	local auth_timer = vim.loop.new_timer()
	auth_timer:start(5000, 0, vim.schedule_wrap(function()
		-- Check if job is still running
		if exit_code == nil and not auth_window_shown then
			auth_window_shown = true
			vim.notify('Authentication may be required - showing auth window...', vim.log.levels.WARN)
			
			local stderr_output = table.concat(stderr_lines, '\n')
			if stderr_output ~= '' then
				show_auth_window(stderr_output)
			else
				show_auth_window("Waiting for authentication...\n\nThe CLI is taking longer than expected.\nCheck your terminal for authentication prompts.")
			end
			
			vim.notify('Waiting for authentication to complete...', vim.log.levels.WARN)
		end
		auth_timer:close()
	end))

	-- Set up a timeout timer (5 minutes max)
	local timeout_timer = vim.loop.new_timer()
	timeout_timer:start(300000, 0, vim.schedule_wrap(function()
		if exit_code == nil then
			-- Still running after 5 minutes - kill it
			vim.fn.jobstop(job_id)
			callback(nil, "Command timed out after 5 minutes")
		end
		timeout_timer:close()
	end))
end

return M
