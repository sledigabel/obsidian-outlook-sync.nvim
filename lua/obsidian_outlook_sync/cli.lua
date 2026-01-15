-- CLI invocation module
-- Handles subprocess calls to outlook-md CLI

local M = {}

-- Show a floating window with authentication instructions
local function show_auth_window(stderr_output)
	-- Create a buffer for the floating window
	local buf = vim.api.nvim_create_buf(false, true)

	-- Split stderr output into lines
	local lines = vim.split(stderr_output, '\n', { plain = true })

	-- Set buffer content
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Calculate window size
	local width = 60
	local height = #lines + 2

	-- Get editor dimensions
	local ui = vim.api.nvim_list_uis()[1]
	local win_width = ui.width
	local win_height = ui.height

	-- Calculate centered position
	local row = math.floor((win_height - height) / 2)
	local col = math.floor((win_width - width) / 2)

	-- Create floating window
	local win = vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		row = row,
		col = col,
		style = 'minimal',
		border = 'rounded',
		title = ' Outlook Authentication ',
		title_pos = 'center',
	})

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, 'modifiable', false)
	vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')

	-- Add keybinding to close the window
	vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })

	-- Show instruction at bottom
	vim.notify('Press q or <Esc> to close this window', vim.log.levels.INFO)
end

-- invoke_cli executes the outlook-md CLI and returns parsed JSON output
-- @param command string: CLI command to run (e.g., "today")
-- @param opts table: options { cli_path, timezone, format }
-- @return table|nil: parsed JSON output (CLIOutput schema)
-- @return string|nil: error message if failed
function M.invoke_cli(command, opts)
	opts = opts or {}
	local cli_path = opts.cli_path or 'outlook-md'
	local timezone = opts.timezone or 'Local'
	local format = opts.format or 'json'

	-- Build command arguments
	local cmd_str = string.format('%s %s --format %s --tz %s 2>&1',
		vim.fn.shellescape(cli_path),
		vim.fn.shellescape(command),
		vim.fn.shellescape(format),
		vim.fn.shellescape(timezone)
	)

	-- Execute command and capture both stdout and stderr
	local result = vim.fn.system(cmd_str)
	local exit_code = vim.v.shell_error

	-- Check if output contains authentication prompts
	if result:match('To authenticate:') or result:match('Visit:') or result:match('Enter code:') then
		-- Show authentication window
		show_auth_window(result)

		-- Wait for user to authenticate (poll until CLI completes)
		vim.notify('Waiting for authentication... (this may take a moment)', vim.log.levels.WARN)

		-- Re-run the command after showing the prompt
		-- The user will authenticate in browser while we wait
		result = vim.fn.system(cmd_str)
		exit_code = vim.v.shell_error
	end

	-- Check for errors
	if exit_code ~= 0 then
		return nil, string.format("outlook-md exited with code %d: %s", exit_code, result)
	end

	-- Parse JSON output (filter out any remaining stderr messages)
	local json_start = result:find('{')
	if json_start then
		result = result:sub(json_start)
	end

	local ok, parsed = pcall(vim.json.decode, result)
	if not ok then
		return nil, string.format("Failed to parse CLI output as JSON: %s", parsed)
	end

	-- Validate schema version
	if parsed.version ~= 1 then
		return nil, string.format("Unsupported CLI output version: %d (expected 1)", parsed.version)
	end

	return parsed, nil
end

return M
