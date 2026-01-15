# Research Findings: Outlook Calendar Sync

**Feature**: Outlook Calendar Sync to Obsidian Markdown
**Branch**: 001-outlook-md-sync
**Date**: 2026-01-07
**Status**: Completed

## Overview

This document captures research findings for technical unknowns identified in the implementation plan. Each section documents the chosen approach, rationale, alternatives considered, implementation notes, and references.

## 1. Microsoft Graph API Device-Code Flow

### Decision

Use `golang.org/x/oauth2` package with device code flow configuration for Microsoft Graph authentication.

### Rationale

- **Official Support**: `golang.org/x/oauth2` is the canonical OAuth2 library for Go, maintained by the Go team
- **Device Code Built-in**: Provides native support for device code flow via `oauth2.DeviceAuthConfig`
- **Automatic Token Refresh**: Handles token refresh transparently when using `oauth2.TokenSource`
- **Well-Documented**: Extensive documentation and examples available
- **Microsoft Graph Compatible**: Works seamlessly with Microsoft identity platform

### Alternatives Considered

1. **Direct HTTP Client**: Manually implement OAuth2 flows
   - **Rejected**: Too error-prone, requires manual token refresh logic, no benefit over established library

2. **Third-party Auth Libraries**: E.g., `github.com/AzureAD/microsoft-authentication-library-for-go` (MSAL Go)
   - **Rejected**: Adds unnecessary dependency, `oauth2` package is sufficient for device code flow

### Implementation Notes

**Device Code Flow Setup**:
```go
import (
    "golang.org/x/oauth2"
    "golang.org/x/oauth2/microsoft"
)

config := &oauth2.Config{
    ClientID:    clientID,  // From Keychain
    Scopes:      []string{"Calendars.Read", "offline_access"},
    Endpoint:    microsoft.AzureADEndpoint(tenantID),
}

// Initiate device code flow
deviceCodeResp, err := config.DeviceAuth(ctx)
// Display deviceCodeResp.VerificationURIComplete and UserCode to user

// Poll for token
token, err := config.DeviceAccessToken(ctx, deviceCodeResp)

// Use TokenSource for automatic refresh
tokenSource := config.TokenSource(ctx, token)
```

**Token Caching**:
- Store `*oauth2.Token` as JSON in `~/.outlook-md/token-cache`
- Set file permissions to `0600` immediately after writing
- Load cached token and create `TokenSource` for automatic refresh

**Required Scopes**:
- `Calendars.Read`: Read user's calendar events (minimum required)
- `offline_access`: Obtain refresh token for long-lived sessions

### References

- [OAuth2 Package Documentation](https://pkg.go.dev/golang.org/x/oauth2)
- [Microsoft Identity Platform Device Code Flow](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-device-code)
- [Microsoft Graph Calendar API](https://learn.microsoft.com/en-us/graph/api/user-list-calendarview)

---

## 2. Token Storage Security on macOS

### Decision

Use direct `security` CLI invocation for macOS Keychain access instead of Go packages.

### Rationale

- **Simplicity**: `security` CLI is standard on macOS, no external dependencies
- **Reliability**: Apple's official tool, guaranteed to work across macOS versions
- **Go Execution**: Easy to invoke via `exec.Command()` in Go
- **No CGo**: Avoids CGo requirements that would complicate cross-compilation

### Alternatives Considered

1. **`github.com/99designs/keyring`**: Cross-platform keyring library
   - **Rejected**: Adds dependency, more complex than needed, overkill for macOS-only initial release

2. **`github.com/keybase/go-keychain`**: Direct Go bindings to macOS Security framework
   - **Rejected**: Requires CGo, complicates build process, not significantly better than CLI invocation

### Implementation Notes

**Service Name and Account Keys**:
- Service: `com.github.obsidian-outlook-sync`
- Accounts: `client-id`, `tenant-id`

**Read from Keychain**:
```go
cmd := exec.Command("security", "find-generic-password",
    "-s", "com.github.obsidian-outlook-sync",
    "-a", "client-id",
    "-w")  // Print password only
output, err := cmd.Output()
clientID := strings.TrimSpace(string(output))
```

**Write to Keychain** (user responsibility, documented in README):
```bash
security add-generic-password \
  -s com.github.obsidian-outlook-sync \
  -a client-id \
  -w '<YOUR_CLIENT_ID>'
```

**Error Handling**:
- `security` returns exit code 44 if item not found → clear error message with setup instructions
- `security` returns exit code 36 if user denies access → prompt for keychain access

**Fallback for Non-macOS**:
- Linux/Windows: Use environment variables `OUTLOOK_MD_CLIENT_ID` and `OUTLOOK_MD_TENANT_ID`
- Check env vars first, then Keychain (macOS only), then error

### References

- [`security` man page](https://ss64.com/osx/security.html)
- [macOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

---

## 3. Neovim Lua Buffer Manipulation

### Decision

Use `vim.api.nvim_buf_get_lines()` and `vim.api.nvim_buf_set_lines()` for atomic buffer updates.

### Rationale

- **Atomic Replacement**: `nvim_buf_set_lines` replaces a range of lines atomically
- **Built-in API**: No external dependencies, works in all Neovim 0.5+ versions
- **Precise Control**: Can replace exact line ranges (start_line to end_line)
- **Undo-Friendly**: Creates single undo point for entire replacement

### Alternatives Considered

1. **Line-by-line updates**: Iterate and update each line individually
   - **Rejected**: Not atomic, creates multiple undo points, risk of partial updates on error

2. **Temp buffer swap**: Build in temp buffer, swap with current buffer
   - **Rejected**: Loses buffer-local state (variables, marks, folds), over-complicated

### Implementation Notes

**Read Buffer Lines**:
```lua
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
-- bufnr: buffer handle (0 for current)
-- 0: start line (0-indexed)
-- -1: end line (-1 = end of buffer)
-- false: strict_indexing (false = clamp to valid range)
```

**Parse for Markers**:
```lua
local start_line, end_line = nil, nil
for i, line in ipairs(lines) do
  if line:match('<!%-%-  AGENDA_START %-%->') then
    start_line = i  -- 1-indexed in Lua, convert to 0-indexed for API
  elseif line:match('<!%-%-  AGENDA_END %-%->') then
    end_line = i
    break
  end
end

if not start_line or not end_line then
  error('AGENDA_START or AGENDA_END marker not found')
end
```

**Atomic Replace**:
```lua
local new_lines = {}  -- Build new lines for managed region
-- ... populate new_lines with rendered events ...

-- Replace lines between markers (inclusive)
vim.api.nvim_buf_set_lines(
  bufnr,
  start_line - 1,  -- Convert to 0-indexed
  end_line,        -- End is exclusive in API
  false,           -- strict_indexing
  new_lines
)
```

**Error Handling**:
- Wrap all operations in `pcall()` to catch errors
- On any error, do not modify buffer
- Display clear error message via `vim.notify()`

**Whitespace Preservation**:
- `nvim_buf_get_lines` returns lines exactly as stored (tabs/spaces preserved)
- `nvim_buf_set_lines` writes lines exactly as provided
- No automatic normalization occurs

### References

- [Neovim API Documentation](https://neovim.io/doc/user/api.html#api-buffer)
- [nvim_buf_get_lines](https://neovim.io/doc/user/api.html#nvim_buf_get_lines())
- [nvim_buf_set_lines](https://neovim.io/doc/user/api.html#nvim_buf_set_lines())

---

## 4. Deterministic Sorting in Go and Lua

### Decision

- **Go**: Use `sort.SliceStable()` with custom multi-key comparison function
- **Lua**: Use `table.sort()` with custom comparator function

### Rationale

- **Stable Sort**: `SliceStable` maintains relative order of equal elements (deterministic)
- **Multi-Key Support**: Custom comparator allows primary/secondary/tertiary sort keys
- **Standard Library**: No external dependencies
- **Locale-Independent**: Use `strings.ToLower()` for case-insensitive comparison (ASCII/UTF-8)

### Alternatives Considered

1. **`sort.Slice()`**: Non-stable sort
   - **Rejected**: Non-deterministic for equal elements (violates Constitution Principle I)

2. **Manual Sorting**: Implement custom sorting algorithm
   - **Rejected**: Reinventing wheel, `SliceStable` is optimized and tested

### Implementation Notes

**Go Multi-Key Attendee Sorting**:
```go
import (
    "sort"
    "strings"
)

func sortAttendees(attendees []Attendee) {
    sort.SliceStable(attendees, func(i, j int) bool {
        a, b := attendees[i], attendees[j]

        // Primary: type (required < optional < resource)
        typeOrder := map[string]int{"required": 0, "optional": 1, "resource": 2}
        if typeOrder[a.Type] != typeOrder[b.Type] {
            return typeOrder[a.Type] < typeOrder[b.Type]
        }

        // Secondary: email (case-insensitive)
        emailA := strings.ToLower(a.Email)
        emailB := strings.ToLower(b.Email)
        if emailA != emailB {
            return emailA < emailB
        }

        // Tertiary: name (case-insensitive)
        nameA := strings.ToLower(a.Name)
        nameB := strings.ToLower(b.Name)
        return nameA < nameB
    })
}
```

**Lua Event Chronological Sorting**:
```lua
table.sort(events, function(a, b)
  -- Sort by start time (RFC3339 timestamps compare lexicographically)
  return a.start < b.start
end)
```

**Lua Stable Sort Note**:
- Lua `table.sort()` is **not guaranteed stable** across implementations
- For deterministic results, ensure comparison function has no ties (always returns true/false for unequal elements)
- For events, RFC3339 timestamps are unique enough (sub-second precision)

### References

- [Go sort package](https://pkg.go.dev/sort)
- [Lua table.sort](https://www.lua.org/manual/5.1/manual.html#pdf-table.sort)

---

## 5. JSON Schema Versioning Strategy

### Decision

Use integer `version` field in JSON root with semantic versioning semantics for data contracts.

### Rationale

- **Explicit Versioning**: Plugin can reject unsupported versions immediately
- **Forward Compatibility**: Plugin ignores unknown fields (future CLI can add fields)
- **Breaking Change Detection**: Major version increment signals incompatible changes
- **Simple Negotiation**: No content negotiation needed (CLI always outputs current version)

### Alternatives Considered

1. **No Versioning**: Assume contract never changes
   - **Rejected**: Unrealistic, prevents CLI/plugin evolution

2. **Content Negotiation**: Plugin requests specific version via CLI flag
   - **Rejected**: Over-complicated for CLI tool, HTTP-style negotiation unnecessary

3. **API-Style Versioning**: `/v1/events`, `/v2/events` paths
   - **Rejected**: Not applicable to CLI stdout (no paths/routes)

### Implementation Notes

**Version Field**:
```json
{
  "version": 1,
  "timezone": "...",
  "window": {...},
  "events": [...]
}
```

**Plugin Version Check**:
```lua
local function validate_cli_output(data)
  if type(data.version) ~= 'number' then
    error('CLI output missing version field')
  end

  if data.version ~= 1 then
    error(string.format('Unsupported CLI output version: %d (plugin expects version 1)', data.version))
  end

  -- Continue with validation...
end
```

**Versioning Rules**:
- **Version 1 → 2**: Breaking change (e.g., rename required field, change field type)
  - Plugin must be updated to support v2 explicitly
- **Add optional field**: No version change, forward compatible
  - Plugin ignores unknown fields (`additionalProperties: true` in schema)
- **Remove deprecated field**: Major version increment (v1 → v2)

**Schema Evolution Example**:
```
v1: { "version": 1, "events": [...] }
v1.1: { "version": 1, "events": [...], "newOptionalField": "..." }  ← Plugin v1 ignores
v2: { "version": 2, "events_renamed": [...] }  ← Plugin v1 rejects
```

### References

- [Semantic Versioning](https://semver.org/)
- [JSON Schema Best Practices](https://json-schema.org/understanding-json-schema/reference/generic.html)

---

## 6. Testing Microsoft Graph Interactions

### Decision

Use Go interfaces for Microsoft Graph client with `httptest.Server` for mocked integration tests.

### Rationale

- **Interface-Based Mocking**: Define `GraphClient` interface, swap implementations for tests
- **No External Dependencies**: `httptest` is in Go standard library
- **Realistic Tests**: Mock server simulates actual HTTP responses
- **Fast Execution**: No network calls in tests

### Alternatives Considered

1. **Record/Replay Library**: E.g., `gopkg.in/dnaeon/go-vcr.v3`
   - **Rejected**: Adds dependency, overkill for our use case, test fixtures simpler

2. **Mock Graph SDK**: Mock generated SDK types
   - **Rejected**: SDK types are concrete (not interfaces), requires wrapper layer anyway

### Implementation Notes

**Define Interface**:
```go
type GraphClient interface {
    GetCalendarView(ctx context.Context, start, end time.Time) ([]Event, error)
}

type graphClientImpl struct {
    httpClient *http.Client
    baseURL    string
}

func (c *graphClientImpl) GetCalendarView(ctx context.Context, start, end time.Time) ([]Event, error) {
    // Implementation using c.httpClient
}
```

**Mock Server for Tests**:
```go
import (
    "net/http"
    "net/http/httptest"
    "testing"
)

func TestGetCalendarView(t *testing.T) {
    // Create mock server
    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Verify request
        if r.URL.Path != "/me/calendarView" {
            t.Errorf("unexpected path: %s", r.URL.Path)
        }

        // Return mock response
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        w.Write([]byte(`{"value": [{"id": "test1", "subject": "Meeting"}]}`))
    }))
    defer server.Close()

    // Use mock server URL
    client := &graphClientImpl{
        httpClient: server.Client(),
        baseURL:    server.URL,
    }

    events, err := client.GetCalendarView(context.Background(), time.Now(), time.Now().Add(24*time.Hour))
    // Assert results...
}
```

**Test Fixtures**:
Create JSON files in `testdata/` directory:
- `testdata/calendar_response_empty.json`: No events
- `testdata/calendar_response_single.json`: Single event
- `testdata/calendar_response_many.json`: 20+ events with attendees
- `testdata/calendar_response_allday.json`: All-day event

**Load Fixtures in Tests**:
```go
func loadFixture(t *testing.T, filename string) []byte {
    data, err := os.ReadFile(filepath.Join("testdata", filename))
    if err != nil {
        t.Fatalf("failed to load fixture: %v", err)
    }
    return data
}
```

### References

- [httptest Package](https://pkg.go.dev/net/http/httptest)
- [Go Testing Best Practices](https://go.dev/doc/tutorial/add-a-test)

---

## 7. Meaningful Notes Detection Algorithm

### Decision

Implement simple line-by-line scan checking for non-blank, non-header, non-scaffold lines.

### Rationale

- **Simplicity**: Linear scan is O(n) where n = number of lines (typically < 50)
- **Clear Rules**: Explicit whitelist of "not meaningful" patterns
- **Fast**: Sufficient performance for typical notes pockets
- **Testable**: Easy to write comprehensive unit tests

### Alternatives Considered

1. **Regex-Based**: Complex regex to match all patterns
   - **Rejected**: Less readable, harder to maintain, no performance benefit

2. **AST Parsing**: Parse markdown structure
   - **Rejected**: Overkill, adds complexity, notes pocket is simple text

### Implementation Notes

**Algorithm**:
```lua
function is_meaningful(notes_pocket)
  local lines = vim.split(notes_pocket, '\n')

  for _, line in ipairs(lines) do
    -- Trim whitespace
    local trimmed = line:match('^%s*(.-)%s*$')

    -- Skip blank lines
    if trimmed ~= '' then
      -- Skip section headers
      if not (trimmed == '- Agenda:' or
              trimmed == '- Organizer:' or
              trimmed == '- Invitees:' or
              trimmed == '- Notes:') then
        -- Skip scaffold lines
        if not trimmed:match('^%- <auto>') then
          -- Found meaningful content!
          return true
        end
      end
    end
  end

  -- No meaningful lines found
  return false
end
```

**Edge Cases**:
- Only whitespace: `false` (all lines blank)
- Only headers: `false` (only section headers)
- Only scaffold: `false` (only `- <auto>` lines)
- One user line: `true` (even if just "- TODO")
- Mixed content: `true` (has at least one meaningful line)

**Performance**:
- Worst case: Scan all lines if no meaningful content
- Typical case: Exit early on first meaningful line
- No backtracking or complex parsing

### References

- Lua string patterns: [Lua 5.1 Reference Manual](https://www.lua.org/manual/5.1/manual.html#5.4.1)

---

## 8. Neovim Plugin Manager Integration

### Decision

Support Lazy.nvim as primary plugin manager, with compatibility for vim-plug and packer.nvim.

### Rationale

- **Modern Standard**: Lazy.nvim is the current de facto standard for Neovim plugin management (2024-2026)
- **Lazy Loading**: Built-in support for lazy loading, performance benefits
- **Simple Configuration**: Declarative Lua-based configuration
- **Backward Compatibility**: Plugin structure works with older managers (vim-plug, packer)

### Alternatives Considered

1. **vim-plug Only**: Support vim-plug exclusively
   - **Rejected**: Outdated, most modern Neovim users have migrated to Lazy.nvim

2. **Packer.nvim**: Use Packer as primary
   - **Rejected**: Packer is no longer actively maintained, author recommends Lazy.nvim

### Implementation Notes

**Lazy.nvim Plugin Spec**:
```lua
-- In user's Neovim config (e.g., ~/.config/nvim/lua/plugins/outlook-sync.lua)
return {
  'your-username/obsidian-outlook-sync',

  -- Optional: Lazy load on command
  cmd = { 'OutlookAgendaToday' },

  -- Optional: Lazy load on filetype
  ft = { 'markdown' },

  -- Configuration function
  config = function()
    require('obsidian_outlook_sync').setup({
      timezone = 'America/New_York',
      -- other config options...
    })
  end,

  -- Optional: Dependencies (none for this plugin)
  dependencies = {},
}
```

**Plugin Structure for Compatibility**:
```
lua/obsidian_outlook_sync/
├── init.lua       -- Main entry point, exports setup()
├── cli.lua        -- CLI invocation
├── parser.lua     -- Buffer parsing
├── merger.lua     -- Event merging
├── renderer.lua   -- Markdown rendering
└── config.lua     -- Configuration management

plugin/
└── obsidian_outlook_sync.vim  -- Vim command registration (for vim-plug compat)

doc/
└── obsidian-outlook-sync.txt  -- Vim help documentation
```

**Setup Function** (in `lua/obsidian_outlook_sync/init.lua`):
```lua
local M = {}

M.setup = function(opts)
  opts = opts or {}
  require('obsidian_outlook_sync.config').set(opts)

  -- Register command
  vim.api.nvim_create_user_command('OutlookAgendaToday', function()
    require('obsidian_outlook_sync.cli').sync_today()
  end, { desc = 'Sync Outlook calendar for today' })
end

return M
```

**vim-plug Compatibility** (in `plugin/obsidian_outlook_sync.vim`):
```vim
if exists('g:loaded_obsidian_outlook_sync')
  finish
endif
let g:loaded_obsidian_outlook_sync = 1

command! -nargs=0 OutlookAgendaToday lua require('obsidian_outlook_sync.cli').sync_today()
```

### References

- [Lazy.nvim Documentation](https://github.com/folke/lazy.nvim)
- [Neovim Plugin Structure](https://neovim.io/doc/user/lua-guide.html#lua-guide-plugin)

---

## Summary

All Phase 0 research tasks have been completed. Key decisions:

1. **Microsoft Graph Auth**: Use `golang.org/x/oauth2` device code flow
2. **Keychain Storage**: Direct `security` CLI invocation (macOS)
3. **Buffer Manipulation**: `nvim_buf_set_lines` for atomic updates
4. **Sorting**: `sort.SliceStable` (Go) and `table.sort` (Lua)
5. **Versioning**: Integer version field with semantic versioning rules
6. **Testing**: Interface-based mocking with `httptest.Server`
7. **Notes Detection**: Simple line-by-line scan algorithm
8. **Plugin Manager**: Lazy.nvim primary, vim-plug/packer compatible

All decisions prioritize simplicity, standard library usage, and alignment with Constitution principles (determinism, testability, developer ergonomics).

## Next Steps

Proceed to Phase 1: Generate design artifacts (data-model.md, contracts, quickstart.md) using research findings.