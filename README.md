# obsidian-outlook-sync

Sync your Microsoft Outlook/M365 calendar events directly into your Obsidian daily notes within Neovim. This plugin maintains a managed region in your markdown files that automatically updates with your calendar events while preserving your personal notes.

## Features

### ✅ Currently Implemented (Phase 3 - MVP)

- **Today's Calendar Sync**: Fetch and display today's calendar events (00:00-24:00) in your notes
- **Managed Regions**: Automatically updates content between `<!-- AGENDA_START -->` and `<!-- AGENDA_END -->` markers
- **Rich Event Details**: Shows event times, subjects, locations, organizers, and attendees
- **All-Day Event Support**: Properly handles all-day events vs timed events
- **Timezone Support**: Respects your local timezone or custom timezone settings
- **Error Handling**: Clear error messages for authentication, network, and parsing issues
- **Atomic Updates**: Buffer updates are atomic to prevent data corruption

### 🚧 Coming Soon

- **Notes Preservation**: Keep your personal notes when refreshing calendar events (Phase 4)
- **Device-Code Authentication**: First-time OAuth2 setup flow (Phase 5)
- **Extended Time Ranges**: Tomorrow, this week, custom date ranges (Phase 6+)
- **Event Filtering**: Hide declined events, filter by calendar (Phase 7+)

## Architecture

This project consists of two components:

1. **`outlook-md` CLI** (Go): Authenticates with Microsoft Graph API and outputs calendar events as JSON
2. **`obsidian-outlook-sync` Plugin** (Lua): Neovim plugin that parses buffers, invokes CLI, renders markdown

## Prerequisites

- **Go 1.21+** (to build the CLI)
- **Neovim 0.5+** (for Lua plugin support)
- **Microsoft 365 Account** with calendar access
- **macOS** (for Keychain credential storage; Linux/Windows support coming)

## Installation

### Step 1: Install the CLI

```bash
# Clone the repository
git clone https://github.com/your-org/obsidian-outlook-sync.nvim.git
cd obsidian-outlook-sync.nvim

# Build the CLI
make build

# Install to /usr/local/bin (requires sudo)
sudo make install

# Or install to user directory (no sudo required)
cp bin/outlook-md ~/.local/bin/
```

Verify the CLI is installed:

```bash
outlook-md --version
# Should output: outlook-md version 0.1.0
```

### Step 2: Install the Neovim Plugin

#### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'your-org/obsidian-outlook-sync.nvim',
  dependencies = {},
  build = 'make build',  -- Build CLI when plugin updates
  config = function()
    require('obsidian_outlook_sync').setup({
      cli_path = 'outlook-md',  -- Path to CLI binary
      timezone = 'Europe/London',  -- Your timezone (default is 'Local')
    })
  end,
}
```

#### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'your-org/obsidian-outlook-sync.nvim',
  run = 'make build',  -- Build CLI when plugin updates
  config = function()
    require('obsidian_outlook_sync').setup({
      cli_path = 'outlook-md',
      timezone = 'Europe/London',
    })
  end
}
```

#### Manual Installation

```bash
# Copy plugin files to Neovim config
mkdir -p ~/.config/nvim/lua/obsidian_outlook_sync
cp -r lua/obsidian_outlook_sync/* ~/.config/nvim/lua/obsidian_outlook_sync/
```

Then add to your `init.lua`:

```lua
require('obsidian_outlook_sync').setup({
  cli_path = 'outlook-md',
  timezone = 'Europe/London',
})
```

## Updating

When the repository updates, you need to rebuild the CLI to get the latest changes.

### Automatic Updates (Recommended)

If you're using **lazy.nvim** or **packer.nvim** with the `build`/`run` parameter as shown above, the CLI will automatically rebuild when you update the plugin:

```vim
" For lazy.nvim users
:Lazy update obsidian-outlook-sync.nvim

" For packer.nvim users
:PackerUpdate
```

### Manual Updates

If you installed manually or need to rebuild:

```bash
# Navigate to plugin directory
cd ~/.local/share/nvim/site/pack/*/start/obsidian-outlook-sync.nvim
# Or for lazy.nvim:
cd ~/.local/share/nvim/lazy/obsidian-outlook-sync.nvim

# Pull latest changes
git pull

# Rebuild CLI
make build

# Reinstall to system path (if you installed to /usr/local/bin)
sudo make install

# Or copy to user directory
cp bin/outlook-md ~/.local/bin/
```

After updating, verify the new version:

```bash
outlook-md --version
```

Then restart Neovim to load the updated Lua plugin files.

## Configuration

### Step 3: Set Up Authentication

**⚠️ CRITICAL - REQUIRED TO WORK:**

You **must** set this environment variable for the plugin to work:

```bash
# Add this to your ~/.zshrc or ~/.bashrc
export OUTLOOK_MD_ACCESS_TOKEN="your-access-token-here"
```

After adding this line, reload your shell:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

**How to get an access token:**

The access token is a temporary credential that allows the CLI to access your Microsoft calendar. Unfortunately, getting one manually is complex (Phase 5 will automate this with device-code flow).

**Quick method (for testing):**
1. Go to [Microsoft Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)
2. Sign in with your Microsoft account
3. Click "Calendars" → Try any calendar endpoint (e.g., `/me/calendar`)
4. Open browser DevTools (F12) → Network tab
5. Look for the request, find the `Authorization: Bearer <token>` header
6. Copy the token (the long string after "Bearer ")
7. Set it as `OUTLOOK_MD_ACCESS_TOKEN`

**Note:** Tokens expire (typically after 1 hour). This is temporary until Phase 5 implements automatic authentication.

#### Optional: Client ID and Tenant ID (for Phase 5)

These are optional now but will be needed when device-code authentication is implemented:

```bash
# Optional - not needed yet
export OUTLOOK_MD_CLIENT_ID="your-client-id"
export OUTLOOK_MD_TENANT_ID="your-tenant-id"
```

Or store them in macOS Keychain:

```bash
# Optional - for future use
security add-generic-password \
  -s "com.github.obsidian-outlook-sync" \
  -a "client-id" \
  -w "your-client-id"

security add-generic-password \
  -s "com.github.obsidian-outlook-sync" \
  -a "tenant-id" \
  -w "your-tenant-id"
```

### Step 4: Registering an Azure AD Application (Optional)

This step is optional for now. It will be required in Phase 5 when automatic authentication is implemented.

<details>
<summary>Click to expand Azure AD setup instructions (optional)</summary>

To get your Client ID and Tenant ID:

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** → **App registrations** → **New registration**
3. Name: "Outlook MD CLI"
4. Supported account types: "Accounts in this organizational directory only"
5. Redirect URI: Leave blank for now (device-code flow doesn't need it)
6. Click **Register**
7. Copy the **Application (client) ID** - this is your `CLIENT_ID`
8. Copy the **Directory (tenant) ID** - this is your `TENANT_ID`
9. Navigate to **API permissions** → **Add a permission** → **Microsoft Graph** → **Delegated permissions**
10. Add these permissions:
    - `Calendars.Read` (read calendar events)
    - `User.Read` (basic profile info)
11. Click **Grant admin consent** (if you have admin rights)

</details>

## Usage

### Setting Up Your Daily Note

Add the managed region markers to your markdown file:

```markdown
# Daily Note - 2026-01-07

## My Tasks
- [ ] Review PRs
- [ ] Write documentation

## Calendar

<!-- AGENDA_START -->
<!-- AGENDA_END -->

## Notes
- Meeting went well today
```

### Syncing Calendar Events

1. Open your daily note in Neovim
2. Run the command:

```vim
:OutlookAgendaToday
```

The content between the markers will be replaced with today's calendar events:

```markdown
<!-- AGENDA_START -->
## 09:00-09:30 Team Standup
**Location:** Conference Room A
**Organizer:** Alice Smith
**Attendees:** Bob Jones, Carol White

## 14:00-15:00 Project Review
**Location:** Zoom
**Organizer:** Project Manager
**Attendees:** Dev Team, QA Team

## All Day - Company Holiday
**Organizer:** HR Department

*No events for this time period*
<!-- AGENDA_END -->
```

### Plugin Configuration Options

```lua
require('obsidian_outlook_sync').setup({
  -- Path to outlook-md CLI binary
  -- Default: 'outlook-md' (searches in PATH)
  cli_path = '/usr/local/bin/outlook-md',

  -- Timezone for calendar queries
  -- Default: 'Local' (automatically uses your system timezone)
  --
  -- When set to 'Local', the CLI will automatically detect and use your
  -- system's IANA timezone name (e.g., 'Europe/London', 'America/New_York')
  --
  -- You can also specify an explicit IANA timezone:
  -- Examples: 'Europe/London', 'America/New_York', 'America/Los_Angeles', 'UTC'
  timezone = 'America/Los_Angeles',
})
```

**Important Notes about Timezones:**

- **'Local' timezone**: Automatically detects your system timezone and converts it to a proper IANA timezone name for the Microsoft Graph API. This is the recommended default.
- **Explicit timezones**: You can specify any valid [IANA timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) (e.g., `Europe/London`, `America/New_York`, `Asia/Tokyo`)
- **Why this matters**: The Microsoft Graph API requires proper IANA timezone names and doesn't accept "Local" directly. The CLI handles this conversion automatically.

### CLI Usage (Advanced)

You can also use the CLI directly:

```bash
# Use system timezone (automatically converted to IANA name)
outlook-md today --tz Local

# Get today's events as JSON with explicit timezone
outlook-md today --format json --tz Europe/London

# Use different timezone
outlook-md today --tz America/New_York

# Use UTC
outlook-md today --tz UTC

# Output to file
outlook-md today --format json --tz Local > calendar.json
```

### CLI Options

```
outlook-md <command> [options]

Commands:
  today    Fetch today's calendar events (00:00-24:00)

Options:
  --format <format>   Output format (default: json)
  --tz <timezone>     Timezone for calendar view (default: Local)
  --version           Print version and exit
  --help              Show help message

Examples:
  outlook-md today --format json --tz America/New_York
  outlook-md today --tz UTC
```

## Troubleshooting

### Quick Checklist

Before troubleshooting, ensure you have:

1. ✅ **Set the access token** (required):
   ```bash
   export OUTLOOK_MD_ACCESS_TOKEN="your-token-here"
   ```
   Verify it's set:
   ```bash
   echo $OUTLOOK_MD_ACCESS_TOKEN
   ```

2. ✅ **Reloaded your shell** after setting the variable:
   ```bash
   source ~/.zshrc  # or ~/.bashrc
   ```

3. ✅ **Restarted Neovim** after setting the variable

### Error: "no access token available"

**Cause**: The CLI can't find the `OUTLOOK_MD_ACCESS_TOKEN` environment variable.

**Solution**:

1. Set the environment variable in your shell config file:
   ```bash
   echo 'export OUTLOOK_MD_ACCESS_TOKEN="your-token-here"' >> ~/.zshrc
   ```

2. Reload your shell:
   ```bash
   source ~/.zshrc
   ```

3. Verify it's set:
   ```bash
   echo $OUTLOOK_MD_ACCESS_TOKEN
   # Should print your token
   ```

4. Restart Neovim

**Note**: If you're using Neovim inside a GUI app (like Neovim-Qt), make sure environment variables are set system-wide, not just in your terminal.

### Error: "Could not find AGENDA_START and AGENDA_END markers"

**Cause**: Your markdown file doesn't have the required markers.

**Solution**: Add these markers to your file:

```markdown
<!-- AGENDA_START -->
<!-- AGENDA_END -->
```

### Error: "outlook-md exited with code 1"

**Cause**: CLI encountered an error (auth, network, parsing, etc.)

**Solution**: Run the CLI directly to see the full error:

```bash
outlook-md today --format json --tz Local
```

Common issues:
- **Authentication failure**: Check your `OUTLOOK_MD_ACCESS_TOKEN` is valid
- **Network error**: Check internet connection and firewall settings
- **Invalid timezone**: Use a valid IANA timezone (e.g., `America/New_York`)

### Error: "TimeZoneNotSupportedException"

**Full error**: `Graph API returned status 400: TimeZoneNotSupportedException: The following TimeZone value is not supported`

**Cause**: You're using an old version of the CLI that doesn't properly convert "Local" timezone.

**Solution**:

1. Update to the latest version:
   ```bash
   cd ~/.local/share/nvim/lazy/obsidian-outlook-sync.nvim  # or your plugin path
   git pull
   make build
   ```

2. Or use an explicit IANA timezone instead of "Local":
   ```lua
   require('obsidian_outlook_sync').setup({
     timezone = 'Europe/London',  -- or your timezone
   })
   ```

### Error: "Failed to parse CLI output as JSON"

**Cause**: CLI returned invalid JSON (likely an error message to stdout instead of stderr).

**Solution**: Run CLI directly to debug:

```bash
outlook-md today --format json 2>&1
```

### Plugin Not Working

1. **Verify CLI is installed**:
   ```bash
   which outlook-md
   outlook-md --version
   ```

2. **Check Neovim version**:
   ```vim
   :version
   ```
   Requires Neovim 0.5+

3. **Verify plugin is loaded**:
   ```vim
   :lua print(vim.inspect(require('obsidian_outlook_sync').config))
   ```

4. **Check logs**:
   ```vim
   :messages
   ```

## Development

### Project Structure

```
.
├── outlook-md/                  # Go CLI
│   ├── cmd/outlook-md/         # CLI entry point
│   ├── internal/               # Internal packages
│   │   ├── calendar/           # Graph API client
│   │   ├── config/             # Config loading
│   │   └── output/             # Output formatters
│   └── pkg/schema/             # JSON schema (CLI ↔ Plugin contract)
├── lua/obsidian_outlook_sync/  # Neovim plugin
│   ├── init.lua                # Plugin initialization
│   ├── commands.lua            # Command handlers
│   ├── parser.lua              # Buffer parsing
│   ├── cli.lua                 # CLI invocation
│   └── renderer.lua            # Markdown rendering
├── tests/                       # Test suites
│   ├── go/                     # Go tests
│   └── lua/                    # Lua tests (busted)
└── specs/                       # Design specifications
```

### Running Tests

#### Go Tests

```bash
# Run all Go tests
cd outlook-md
go test ./... -v

# Run specific test
go test ./internal/calendar -v -run TestGetCalendarView

# Run integration tests
cd ../tests/go
go test ./... -v
```

#### Lua Tests

```bash
# Install busted (Lua test framework)
luarocks install busted

# Run Lua tests
cd tests/lua
busted parser_spec.lua
busted renderer_spec.lua
```

### Building

```bash
# Build CLI
make build

# Build and install
make install

# Clean build artifacts
make clean

# Run tests
make test
```

## Implementation Status

### Phase 1: Project Setup ✅ Complete
- [x] Go CLI structure
- [x] Neovim plugin structure
- [x] Build system (Makefile)
- [x] Test infrastructure

### Phase 2: Foundational Components ✅ Complete
- [x] JSON schema (contract between CLI and plugin)
- [x] Config loading (Keychain + env vars)
- [x] Graph API client interface
- [x] Test fixtures

### Phase 3: User Story 1 - Initial Calendar Sync ✅ Complete
- [x] CLI: Today's events fetching
- [x] CLI: JSON output formatting
- [x] Plugin: Managed region parsing
- [x] Plugin: CLI invocation
- [x] Plugin: Event rendering
- [x] Plugin: :OutlookAgendaToday command

### Phase 4: User Story 2 - Preserve User Notes 🚧 Next
- [ ] Parse EVENT_ID markers
- [ ] Extract NOTES_START/END pockets
- [ ] Merge old and new events
- [ ] Detect meaningful notes
- [ ] Retain deleted events with meaningful notes

### Phase 5: User Story 3 - First-Time Authentication 🔜 Planned
- [ ] Device-code OAuth2 flow
- [ ] Token caching (~/.outlook-md/token-cache)
- [ ] Automatic token refresh

### Future Phases
- Phase 6: Tomorrow's events
- Phase 7: This week's events
- Phase 8: Event filtering (hide declined, calendar selection)
- Phase 9: Custom date ranges

## Constitution Principles

This project follows 7 core principles:

1. **Determinism**: Same input → same output, no random behavior
2. **Obsidian Safety**: Never modify content outside managed regions
3. **Separation of Concerns**: CLI handles API, plugin handles UI/buffer management
4. **Security**: Minimal Graph scopes, no secrets in git, secure credential storage
5. **Testability**: Interface-based design, comprehensive test coverage
6. **Developer Ergonomics**: Clear error messages, good documentation
7. **Failure Transparency**: Errors propagate clearly to users

See [specs/001-outlook-md-sync/constitution.md](specs/001-outlook-md-sync/constitution.md) for details.

## Contributing

Contributions are welcome! Please:

1. Read the [constitution](specs/001-outlook-md-sync/constitution.md) and [spec](specs/001-outlook-md-sync/spec.md)
2. Follow the existing code style
3. Add tests for new features
4. Update documentation

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

Built with:
- [Microsoft Graph API](https://docs.microsoft.com/en-us/graph/) for calendar access
- [Neovim](https://neovim.io/) for the best text editor experience
- [Go](https://golang.org/) for reliable CLI tooling

---

**Note**: This project is in active development. Phase 3 (MVP) is complete with basic calendar sync. Phase 4 (notes preservation) is next. Authentication flow (Phase 5) requires manual token setup for now.
