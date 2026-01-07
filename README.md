# obsidian-outlook-sync

Sync your Microsoft Outlook/M365 calendar events directly into your Obsidian daily notes within Neovim. This plugin maintains a managed region in your markdown files that automatically updates with your calendar events while preserving your personal notes.

## Features

### ✅ Currently Implemented (Phases 1-7)

- **Today's Calendar Sync**: Fetch and display today's calendar events (00:00-24:00) in your notes
- **Managed Regions**: Automatically updates content between `<!-- AGENDA_START -->` and `<!-- AGENDA_END -->` markers
- **Rich Event Details**: Shows event times, subjects, locations, organizers, attendees with deterministic sorting
- **Notes Preservation**: Your personal notes are preserved when refreshing calendar events
- **Deleted Event Handling**: Events removed from calendar but with your notes are retained with `[deleted]` marker
- **Device-Code Authentication**: Automatic OAuth2 authentication flow with token refresh
- **Secure Credential Storage**: Uses macOS Keychain for client ID and tenant ID storage
- **All-Day Event Support**: Properly handles all-day events vs timed events
- **Timezone Support**: Respects your local timezone or custom timezone settings
- **Attendee Display**: Shows up to 15 attendees with smart truncation for large meetings
- **Error Handling**: Clear error messages for authentication, network, and parsing issues
- **Atomic Updates**: Buffer updates are atomic to prevent data corruption
- **Cross-Platform**: Works on macOS (with Keychain support) and other platforms (environment variables)

### 🚧 Coming Soon

- **Extended Time Ranges**: Tomorrow, this week, custom date ranges (Phase 8)
- **Event Filtering**: Hide declined events, filter by calendar (Phase 9+)

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

The plugin now supports automatic OAuth2 device-code flow authentication! You have two options:

#### Option 1: Automatic Device-Code Flow (Recommended)

1. **Set up Azure AD App Registration** (one-time setup):
   - Go to [Azure Portal](https://portal.azure.com)
   - Navigate to **Azure Active Directory** → **App registrations** → **New registration**
   - Name: "Outlook MD CLI"
   - Supported account types: "Accounts in this organizational directory only"
   - Redirect URI: Leave blank (device-code flow doesn't need it)
   - Click **Register**
   - Copy the **Application (client) ID** and **Directory (tenant) ID**
   - Navigate to **API permissions** → **Add a permission** → **Microsoft Graph** → **Delegated permissions**
   - Add: `Calendars.Read` and `offline_access`
   - Click **Grant admin consent** (if you have admin rights)

2. **Store credentials securely**:

   **macOS Keychain (Recommended)**:
   ```bash
   security add-generic-password \
     -s "com.github.obsidian-outlook-sync" \
     -a "client-id" \
     -w "your-client-id-here"

   security add-generic-password \
     -s "com.github.obsidian-outlook-sync" \
     -a "tenant-id" \
     -w "your-tenant-id-here"
   ```

   **Environment Variables (Alternative)**:
   ```bash
   # Add to ~/.zshrc or ~/.bashrc
   export OUTLOOK_MD_CLIENT_ID="your-client-id-here"
   export OUTLOOK_MD_TENANT_ID="your-tenant-id-here"
   ```

3. **First Run - Device Code Flow**:

   When you run `:OutlookAgendaToday` for the first time, you'll see:
   ```
   To authenticate:
   1. Visit: https://microsoft.com/devicelogin
   2. Enter code: ABC-DEF-GHI

   Waiting for authentication...
   ```

   - Open the URL in your browser
   - Enter the code shown
   - Sign in with your Microsoft account
   - Grant permissions
   - Return to Neovim - sync will complete automatically

4. **Automatic Token Management**:
   - Access token cached in `~/.outlook-md/token.json` (0600 permissions)
   - Automatically refreshes when expired
   - No need to re-authenticate unless token is revoked

#### Option 2: Manual Access Token (Legacy/Testing)

For testing or if device-code flow doesn't work:

```bash
# Add to ~/.zshrc or ~/.bashrc
export OUTLOOK_MD_ACCESS_TOKEN="your-access-token-here"
```

**Getting a manual token** (temporary, expires in ~1 hour):
1. Go to [Microsoft Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)
2. Sign in → Try `/me/calendar` endpoint
3. Open DevTools (F12) → Network tab
4. Find the request → Copy `Authorization: Bearer <token>` value
5. Set as `OUTLOOK_MD_ACCESS_TOKEN`

**Note**: Manual tokens expire quickly. Use device-code flow for production use.

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
<!-- EVENT_ID: event-abc-123 -->
## 09:00-09:30 Team Standup
**Location:** Conference Room A

### Agenda
- <auto> (Add agenda items here)

### Organizer
- <auto> Alice Smith <alice@example.com>

### Invitees
- <auto> Bob Jones <bob@example.com> (required)
- <auto> Carol White <carol@example.com> (required)
- <auto> Diana Lee <diana@example.com> (optional)

### Notes
<!-- NOTES_START -->
- Discussed Q1 priorities
- Action item: Update project timeline
<!-- NOTES_END -->

<!-- EVENT_ID: event-def-456 -->
## 14:00-15:00 Project Review
**Location:** Zoom

### Agenda
- <auto> (Add agenda items here)

### Organizer
- <auto> Project Manager <pm@example.com>

### Invitees
- <auto> Dev Team <dev@example.com> (required)
- <auto> QA Team <qa@example.com> (required)
…and 12 more (total 14)

### Notes
<!-- NOTES_START -->

<!-- NOTES_END -->

<!-- EVENT_ID: event-ghi-789 -->
## All Day - Company Holiday

### Agenda
- <auto> (Add agenda items here)

### Organizer
- <auto> HR Department <hr@example.com>

### Invitees
- <auto> None

### Notes
<!-- NOTES_START -->

<!-- NOTES_END -->
<!-- AGENDA_END -->
```

**Key Features**:
- **EVENT_ID markers**: Used to track events across refreshes
- **Your notes are preserved**: Content in `<!-- NOTES_START/END -->` is kept when you refresh
- **Deleted events retained**: If you've added notes to an event that's later deleted, it's kept with `[deleted]` marker
- **Attendee truncation**: For meetings with 16+ attendees, shows first 15 plus "…and N more"
- **Auto-generated content**: Lines starting with `- <auto>` are managed by the plugin

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

1. ✅ **Set up Azure AD App Registration** and stored credentials (Client ID + Tenant ID)
   - Verify credentials are set:
     ```bash
     # Check Keychain
     security find-generic-password -s com.github.obsidian-outlook-sync -a client-id -w

     # Or check environment variables
     echo $OUTLOOK_MD_CLIENT_ID
     echo $OUTLOOK_MD_TENANT_ID
     ```

2. ✅ **Completed first authentication** via device-code flow
   - Check token cache exists: `ls -la ~/.outlook-md/token.json`

3. ✅ **Restarted Neovim** after setting credentials

### Error: "client ID not found" or "tenant ID not found"

**Cause**: CLI can't find credentials in Keychain or environment variables.

**Solution**:

Store in Keychain:
```bash
security add-generic-password \
  -s "com.github.obsidian-outlook-sync" \
  -a "client-id" \
  -w "your-client-id-here"

security add-generic-password \
  -s "com.github.obsidian-outlook-sync" \
  -a "tenant-id" \
  -w "your-tenant-id-here"
```

Or use environment variables:
```bash
echo 'export OUTLOOK_MD_CLIENT_ID="your-client-id"' >> ~/.zshrc
echo 'export OUTLOOK_MD_TENANT_ID="your-tenant-id"' >> ~/.zshrc
source ~/.zshrc
```

### Error: "authentication failed" or "device code authentication failed"

**Cause**: Device-code flow couldn't complete or token refresh failed.

**Solution**:

1. Delete cached token and re-authenticate:
   ```bash
   rm ~/.outlook-md/token.json
   ```

2. Try syncing again - you'll be prompted for device-code authentication

3. Ensure you completed the browser authentication within the timeout period

### Error: "Keychain access denied"

**Cause**: User denied access to Keychain when CLI tried to read credentials.

**Solution**:

Either grant access in Keychain Access app, or use environment variables:
```bash
export OUTLOOK_MD_CLIENT_ID="your-client-id"
export OUTLOOK_MD_TENANT_ID="your-tenant-id"
```

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

### Phase 4: User Story 2 - Preserve User Notes ✅ Complete
- [x] Parse EVENT_ID markers
- [x] Extract NOTES_START/END pockets
- [x] Merge old and new events
- [x] Detect meaningful notes
- [x] Retain deleted events with meaningful notes

### Phase 5: User Story 3 - First-Time Authentication ✅ Complete
- [x] Device-code OAuth2 flow
- [x] Token caching (~/.outlook-md/token.json)
- [x] Automatic token refresh
- [x] Secure 0600 file permissions

### Phase 6: User Story 4 - Attendee Information Display ✅ Complete
- [x] Deterministic attendee sorting (required → optional → resource)
- [x] Organizer section rendering
- [x] Invitees section with email and type
- [x] Attendee truncation (15+ → "…and N more")
- [x] Event structure: Agenda, Organizer, Invitees, Notes sections

### Phase 7: User Story 5 - Secure Configuration Management ✅ Complete
- [x] macOS Keychain integration via `security` CLI
- [x] Environment variable fallback
- [x] Platform-specific build tags (darwin/other)
- [x] Clear error messages for missing/denied credentials

### Phase 8: User Story 6 - Custom Time Range Queries 🚧 Next
- [ ] Tomorrow's events
- [ ] This week's events
- [ ] Custom date range queries
- [ ] :OutlookAgendaTomorrow command
- [ ] :OutlookAgendaWeek command

### Future Phases
- Phase 9: Polish (error handling, logging, documentation)
- Phase 10: Event filtering (declined events, calendar selection)

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

**Status**: Phases 1-7 complete (58% of roadmap). The system now features:
- ✅ OAuth2 device-code authentication with automatic token refresh
- ✅ Secure credential storage via macOS Keychain
- ✅ User notes preservation across calendar refreshes
- ✅ Rich event details with sorted attendees and smart truncation
- ✅ Deleted event handling with user notes retention

Next up: Phase 8 (Custom Time Range Queries) for tomorrow/week views.
