-- CLI invocation module
-- Handles subprocess calls to outlook-md CLI

local M = {}

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
	local cmd = {
		cli_path,
		command,
		'--format', format,
		'--tz', timezone,
	}

	-- Execute command
	local result = vim.fn.system(cmd)
	local exit_code = vim.v.shell_error

	-- Check for errors
	if exit_code ~= 0 then
		return nil, string.format("outlook-md exited with code %d: %s", exit_code, result)
	end

	-- Parse JSON output
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
