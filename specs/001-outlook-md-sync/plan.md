# Implementation Plan: Outlook Calendar Sync to Obsidian Markdown

**Branch**: `001-outlook-md-sync` | **Date**: 2026-01-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-outlook-md-sync/spec.md`

## Summary

This feature enables Neovim users to sync their Outlook/M365 calendar events into Obsidian markdown notes through a two-component architecture:

1. **Go CLI (outlook-md)**: Authenticates with Microsoft Graph using device-code flow and fetches calendar events, outputting structured JSON
2. **Neovim Plugin (obsidian-outlook-sync)**: Invokes the CLI, parses the current buffer, merges calendar data with existing notes, and renders events in a managed region while preserving user-authored content

The core technical approach prioritizes **deterministic rendering**, **note safety** (never modifying content outside managed regions), and **clean separation** between authentication/data-fetching (Go) and parsing/merging/rendering (Lua).

## Technical Context

**Language/Version**:
- Go 1.21+ (CLI component)
- Lua 5.1/LuaJIT (Neovim plugin, requires Neovim 0.5+)

**Primary Dependencies**:
- **Go CLI**:
  - `golang.org/x/oauth2` for Microsoft Graph OAuth2 device-code flow
  - `microsoft/microsoft-graph-api` Go SDK or direct HTTP client for `/me/calendarView` endpoint
  - macOS `security` CLI tool for Keychain integration (macOS only)
- **Neovim Plugin**:
  - Neovim Lua API (`vim.fn`, `vim.api`, buffer manipulation)
  - JSON parsing (built-in `vim.json` or external library)
  - Lazy.nvim for plugin management (recommended, not required)

**Storage**:
- Token cache: Disk-based file at `~/.outlook-md/token-cache` with 0600 permissions
- Configuration: Apple Keychain (macOS) for client ID and tenant ID
- Calendar data: Ephemeral (fetched on-demand, rendered into user's markdown files)

**Testing**:
- **Go**: `go test` with standard library `testing` package
- **Lua**: Neovim test framework (plenary.nvim or minimal test harness)
- **Integration**: Mocked Microsoft Graph responses using Go interfaces
- **Contract**: JSON schema validation tests ensuring CLI-plugin compatibility

**Target Platform**:
- **CLI**: macOS (initial), Linux (future), Windows (future via WSL or native build)
- **Plugin**: Neovim 0.5+ on any platform where Neovim runs

**Project Type**: Multi-component (CLI + editor plugin) with shared data contract

**Performance Goals**:
- CLI calendar fetch: < 3 seconds for typical day (< 50 events) including network latency
- Plugin parsing + merge + render: < 2 seconds for 50 events on typical hardware
- Full `:OutlookAgendaToday` command: < 10 seconds end-to-end (per SC-001)

**Constraints**:
- Deterministic: Same inputs always produce identical markdown output (byte-for-byte)
- Obsidian safety: Zero risk of modifying content outside managed region
- Token security: File permissions 0600, no token logging
- Read-only: No write operations to Microsoft 365 calendar

**Scale/Scope**:
- **CLI**: Single-user, single-calendar, read-only access
- **Plugin**: Single buffer at a time, one managed region per file
- **Event capacity**: Up to 100 events per day (design supports, typical usage < 20)
- **Codebase**: Estimated 2-3k LOC Go (CLI), 1-2k LOC Lua (plugin), 1k LOC tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Determinism ✅

**Status**: PASS

**Evidence**:
- FR-005 requires deterministic attendee ordering (required > optional > resource > email > name)
- FR-027 specifies exact truncation format ("…and N more (total T)")
- SC-005 explicitly requires byte-for-byte identical output for same inputs
- All time formatting uses explicit HH:MM–HH:MM format with timezone specification
- Event ordering by chronological start time (RFC3339 timestamps are unambiguous)

**No violations**.

### II. Obsidian Safety ✅

**Status**: PASS

**Evidence**:
- FR-016 requires parsing AGENDA_START/AGENDA_END markers to identify managed region
- FR-021 explicitly prohibits modification outside managed region
- FR-020 requires verbatim preservation of content inside NOTES_START/NOTES_END
- FR-023/FR-024 define explicit rules for deleted event retention based on note meaningfulness
- SC-010 success criterion: "Content outside managed region is never modified: byte-identical before and after sync for 100% of refreshes"
- Edge case documented: "How does the system handle multiple managed regions?" → only first pair updated

**No violations**.

### III. Separation of Concerns ✅

**Status**: PASS

**Evidence**:
- FR-001 to FR-013: All CLI responsibilities (auth, Graph API, JSON output, token cache, Keychain)
- FR-014 to FR-030: All plugin responsibilities (Neovim command, buffer parsing, merge logic, rendering)
- FR-013 explicitly prohibits CLI from doing markdown parsing/merging/rendering
- FR-011/FR-012 define versioned JSON schema as clean component boundary
- CLI outputs structured JSON on stdout, errors on stderr; plugin parses and renders
- No shared state or direct coupling between components

**No violations**.

### IV. Security ✅

**Status**: PASS

**Evidence**:
- FR-039: Token cache file must have 0600 permissions
- FR-040/FR-041: Apple Keychain storage for client ID and tenant ID
- FR-042: No token logging or display in output
- FR-043: HTTPS enforcement for all Microsoft Graph API calls
- Threat model section documents 10 security considerations with mitigations
- FR-001 specifies device-code flow (no passwords in CLI)
- FR-055 to FR-060 require README documentation of security setup

**No violations**.

### V. Testability ✅

**Status**: PASS

**Evidence**:
- FR-047 to FR-054: 8 specific test requirements covering critical paths
- FR-053: Microsoft Graph interactions must be mockable
- FR-054: At least one mocked integration test required
- User stories include "Independent Test" sections describing testability
- Design separates pure logic (parsing, merge rules) from I/O (network, file operations)
- Merge logic, meaningful-notes detection, attendee ordering are pure functions

**No violations**.

### VI. Developer Ergonomics ✅

**Status**: PASS

**Evidence**:
- FR-044: `make test` target required
- FR-045: `make build` target required
- FR-046: Build output in `.gitignore`
- FR-055 to FR-064: Comprehensive README requirements (Graph setup, auth flow, Keychain, Lazy.nvim, examples)
- FR-061: Lazy.nvim plugin spec snippet required in README
- FR-063: Command usage documentation required
- CLI-Plugin Contract section provides complete interface documentation

**No violations**.

### VII. Failure Transparency ✅

**Status**: PASS

**Evidence**:
- FR-009: CLI returns non-zero exit code on failure
- FR-010: Error messages only on stderr (when --format json)
- FR-029: Plugin displays CLI error messages to user
- Error handling section in CLI-Plugin Contract defines error format: operation failed, why, what to do next
- FR-119 (Principle VII requirement): "The system MUST NEVER silently corrupt notes on failure"
- Edge case: "What happens when network failures occur?" → non-zero exit, error message, no buffer modification
- Acceptance scenarios include error paths (invalid token, missing markers, CLI not found)

**No violations**.

### Post-Design Re-Check

To be completed after Phase 1 design artifacts are generated. Expected result: PASS with no violations.

## Project Structure

### Documentation (this feature)

```text
specs/001-outlook-md-sync/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── cli-plugin-v1.json   # JSON schema for CLI output
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
outlook-md/                    # Go CLI component
├── cmd/
│   └── outlook-md/
│       └── main.go            # CLI entry point, command routing
├── internal/
│   ├── auth/                  # OAuth2 device-code flow, token cache
│   │   ├── device_flow.go
│   │   ├── token_cache.go
│   │   └── keychain_darwin.go # macOS Keychain integration
│   ├── calendar/              # Microsoft Graph client
│   │   ├── client.go
│   │   └── events.go
│   ├── output/                # JSON formatting and schema
│   │   └── formatter.go
│   └── config/                # Configuration loading
│       └── config.go
├── pkg/
│   └── schema/                # Exported JSON schema types
│       └── v1.go
├── go.mod
├── go.sum
└── Makefile

obsidian-outlook-sync/         # Neovim plugin component (or lua/ at repo root)
├── lua/
│   └── obsidian_outlook_sync/
│       ├── init.lua           # Plugin registration, command setup
│       ├── cli.lua            # CLI invocation, subprocess handling
│       ├── parser.lua         # Buffer parsing, marker detection
│       ├── merger.lua         # Event merging logic, notes preservation
│       ├── renderer.lua       # Markdown generation, formatting
│       └── config.lua         # Plugin configuration (marker customization)
└── doc/
    └── obsidian-outlook-sync.txt  # Vim help documentation

tests/
├── go/                        # Go tests mirror internal/ structure
│   ├── auth/
│   ├── calendar/
│   └── output/
└── lua/                       # Lua tests
    ├── parser_spec.lua
    ├── merger_spec.lua
    └── renderer_spec.lua

.gitignore                     # Must include: bin/, token-cache, *.log
Makefile                       # Root Makefile with build, test, clean, install targets
README.md                      # Primary documentation (per FR-055 to FR-064)
```

**Structure Decision**:

This is a **multi-component project** with two independent codebases that communicate via a JSON contract:

1. **Go CLI (`outlook-md/`)**: Standard Go project layout following [golang-standards/project-layout](https://github.com/golang-standards/project-layout) conventions. `cmd/` for entry points, `internal/` for private packages (auth, calendar, output logic), `pkg/` for public types (schema definitions that could be shared).

2. **Neovim Plugin (`obsidian-outlook-sync/` or `lua/` at root)**: Standard Neovim plugin structure with Lua modules under `lua/obsidian_outlook_sync/`. Each module has a single responsibility (CLI invocation, parsing, merging, rendering).

3. **Tests (`tests/`)**: Mirroring source structure but segregated by language. Go tests use standard `_test.go` convention, Lua tests use `plenary.nvim` or minimal harness.

**Rationale**: This structure directly implements Constitution Principle III (Separation of Concerns) by maintaining clear component boundaries. Each component can be developed, tested, and versioned independently. The CLI is usable standalone for debugging/scripting, and the plugin can theoretically support alternative calendar sources by swapping CLI.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No entries required. All constitution principles are satisfied by the design.

## Phase 0: Research & Technical Discovery

**Status**: In Progress

**Objective**: Resolve all technical unknowns and identify best practices for implementation.

### Research Tasks

See [research.md](./research.md) for detailed findings. Key research areas:

1. **Microsoft Graph API Device-Code Flow**
   - Research OAuth2 device-code grant flow implementation in Go
   - Identify official Microsoft Graph Go SDK vs. direct HTTP client
   - Determine required Graph API scopes and permissions
   - Document token refresh behavior and expiry handling

2. **Token Storage Security on macOS**
   - Research Go bindings for macOS Keychain (Security framework)
   - Evaluate `keyring` package vs. direct `security` CLI invocation
   - Document Keychain service name and account key conventions
   - Determine fallback behavior for non-macOS platforms

3. **Neovim Lua Buffer Manipulation**
   - Research Neovim buffer read/write APIs for atomic updates
   - Identify patterns for parsing markdown with HTML comment markers
   - Determine how to preserve exact whitespace (tabs vs. spaces)
   - Document error handling for missing markers or malformed buffers

4. **Deterministic Sorting in Go and Lua**
   - Research Go `sort.SliceStable` for multi-key sorting (attendee ordering)
   - Document Lua table sorting with custom comparator functions
   - Ensure lowercase string comparison is locale-independent (ASCII/UTF-8)

5. **JSON Schema Versioning Strategy**
   - Research semantic versioning for data contracts
   - Identify forward-compatibility patterns (ignoring unknown fields)
   - Document version negotiation strategies (plugin checks CLI version)

6. **Testing Microsoft Graph Interactions**
   - Research Go interface-based mocking for HTTP clients
   - Identify `httptest` package usage for recording/replaying Graph responses
   - Document test fixtures for various calendar event scenarios (all-day, no location, many attendees)

7. **Meaningful Notes Detection Algorithm**
   - Research string processing for detecting blank lines, headers, scaffold patterns
   - Identify edge cases: only whitespace, only comments, mixed content
   - Document algorithm complexity and performance (linear scan acceptable)

8. **Neovim Plugin Manager Integration**
   - Research Lazy.nvim plugin spec format (init function, dependencies)
   - Document alternative plugin managers (vim-plug, packer.nvim)
   - Identify plugin configuration patterns (setup function, default options)

### Research Deliverables

Each research task will produce:
- **Decision**: Chosen approach (e.g., "Use official microsoft-graph-sdk-go")
- **Rationale**: Why chosen (e.g., "Official support, automatic token refresh, typed API")
- **Alternatives Considered**: What else was evaluated (e.g., "Direct HTTP client - rejected due to manual token refresh logic")
- **Implementation Notes**: Specific guidance (e.g., "Use `msgraph.NewGraphClient()` with custom `http.Client`")
- **References**: Links to documentation, examples, or relevant code

## Phase 1: Design & Contracts

**Status**: Pending (blocked on Phase 0 completion)

**Objective**: Define data models, API contracts, and architectural boundaries.

### Design Artifacts

#### 1. Data Model ([data-model.md](./data-model.md))

**Entities**:

- **CalendarEvent**: Represents a single event from Microsoft Graph
  - Fields: `id` (string), `subject` (string), `isAllDay` (bool), `start` (RFC3339), `end` (RFC3339), `location` (string), `organizer` (Organizer), `attendees` ([]Attendee)
  - Validation: `id` non-empty, `start` < `end`, `attendees` sorted deterministically
  - State: Immutable (value object)

- **Organizer**: Event organizer information
  - Fields: `name` (string), `email` (string)
  - Validation: Email format (informational only, no strict validation)

- **Attendee**: Event attendee information
  - Fields: `name` (string), `email` (string), `type` (enum: required/optional/resource)
  - Validation: Type must be one of three values
  - Ordering: Deterministic by type, then email, then name (all lowercase)

- **ManagedRegion**: Parsed state of agenda block in markdown file
  - Fields: `startLine` (int), `endLine` (int), `events` ([]ParsedEvent)
  - Validation: `startLine` < `endLine`, markers exist
  - Operations: Extract, replace (atomic)

- **ParsedEvent**: Event with user notes from existing markdown
  - Fields: `eventId` (string), `header` (string), `notesPocket` (string), `isDeleted` (bool)
  - Validation: `eventId` matches EVENT_ID marker
  - Operations: Detect meaningful notes, preserve notes pocket

- **CLIOutput** (JSON schema v1): Contract between CLI and plugin
  - Fields: `version` (int), `timezone` (string), `window` {start, end}, `events` ([]CalendarEvent)
  - Validation: Version must be 1, timezone valid IANA, events array present (may be empty)

#### 2. API Contracts ([contracts/cli-plugin-v1.json](./contracts/cli-plugin-v1.json))

**CLI Command Interface**:

```bash
outlook-md today --format json --tz <IANA_TIMEZONE>
outlook-md range <START_RFC3339> <END_RFC3339> --format json --tz <IANA_TIMEZONE>
```

**Exit Codes**:
- `0`: Success (valid JSON on stdout)
- `1`: General error (error message on stderr)
- `2`: Authentication failure (device code URL or re-auth instructions on stderr)
- `3`: Configuration error (missing Keychain entries, invalid config)
- `4`: Network failure (cannot reach Microsoft Graph)

**JSON Schema** (OpenAPI-style definition in `contracts/cli-plugin-v1.json`):

```json
{
  "version": 1,
  "type": "object",
  "required": ["version", "timezone", "window", "events"],
  "properties": {
    "version": {"type": "integer", "const": 1},
    "timezone": {"type": "string", "pattern": "^[A-Z][a-zA-Z/_]+$"},
    "window": {
      "type": "object",
      "required": ["start", "end"],
      "properties": {
        "start": {"type": "string", "format": "date-time"},
        "end": {"type": "string", "format": "date-time"}
      }
    },
    "events": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "subject", "isAllDay", "start", "end", "location", "organizer", "attendees"],
        "properties": {
          "id": {"type": "string", "minLength": 1},
          "subject": {"type": "string"},
          "isAllDay": {"type": "boolean"},
          "start": {"type": "string", "format": "date-time"},
          "end": {"type": "string", "format": "date-time"},
          "location": {"type": "string"},
          "organizer": {
            "type": "object",
            "required": ["name", "email"],
            "properties": {
              "name": {"type": "string"},
              "email": {"type": "string"}
            }
          },
          "attendees": {
            "type": "array",
            "items": {
              "type": "object",
              "required": ["name", "email", "type"],
              "properties": {
                "name": {"type": "string"},
                "email": {"type": "string"},
                "type": {"enum": ["required", "optional", "resource"]}
              }
            }
          }
        }
      }
    }
  }
}
```

**Plugin Configuration Interface**:

```lua
require('obsidian_outlook_sync').setup({
  cli_path = 'outlook-md',         -- Path to CLI binary (default: searches PATH)
  timezone = 'America/New_York',   -- IANA timezone for queries
  markers = {
    agenda_start = '<!-- AGENDA_START -->',
    agenda_end = '<!-- AGENDA_END -->',
    event_id = '<!-- EVENT_ID: %s -->',
    notes_start = '<!-- NOTES_START -->',
    notes_end = '<!-- NOTES_END -->'
  },
  timeout = 30000,                 -- CLI timeout in milliseconds
  on_error = function(err)         -- Custom error handler (optional)
    vim.notify(err, vim.log.levels.ERROR)
  end
})
```

#### 3. Quickstart Guide ([quickstart.md](./quickstart.md))

**Prerequisites**:
- Go 1.21+ installed
- Neovim 0.5+ installed
- Microsoft 365 account with calendar access
- Azure AD application registered (instructions provided)

**5-Minute Setup**:

1. **Register Azure AD Application**:
   ```bash
   # Navigate to https://portal.azure.com → Azure Active Directory → App registrations
   # Create new registration with redirect URI: http://localhost (device code flow)
   # Note: Client ID, Tenant ID
   # Grant API permissions: Calendars.Read, offline_access
   ```

2. **Build CLI**:
   ```bash
   cd outlook-md
   make build
   sudo make install  # Or add bin/ to PATH
   ```

3. **Store Credentials (macOS)**:
   ```bash
   security add-generic-password -s com.github.obsidian-outlook-sync \
     -a client-id -w '<YOUR_CLIENT_ID>'
   security add-generic-password -s com.github.obsidian-outlook-sync \
     -a tenant-id -w '<YOUR_TENANT_ID>'
   ```

4. **Authenticate**:
   ```bash
   outlook-md today --format json --tz America/New_York
   # Follow device code URL, complete auth in browser
   # Token cached at ~/.outlook-md/token-cache
   ```

5. **Install Plugin** (Lazy.nvim):
   ```lua
   {
     'your-github-username/obsidian-outlook-sync',
     config = function()
       require('obsidian_outlook_sync').setup({
         timezone = 'America/New_York'
       })
     end
   }
   ```

6. **Use Plugin**:
   ```markdown
   <!-- AGENDA_START -->
   <!-- AGENDA_END -->
   ```
   Run `:OutlookAgendaToday` in Neovim.

**Verification**:
- CLI test: `outlook-md today --format json --tz UTC | jq .version` should output `1`
- Plugin test: Open markdown file, add markers, run command, verify events appear

### Architecture Decisions

#### AD-001: Use Microsoft Graph SDK for Go

**Decision**: Use official `microsoft-graph-sdk-go` package.

**Rationale**:
- Official Microsoft support and maintenance
- Automatic token refresh handling
- Typed API models for calendar events
- Handles Graph API pagination automatically

**Alternatives Considered**:
- Direct HTTP client with `net/http`: Rejected due to manual token refresh complexity
- Third-party SDK: Rejected due to lack of maintenance and unofficial status

**Impact**: Simplifies CLI implementation, reduces error-prone token management code.

#### AD-002: Use Plenary.nvim for Lua Testing

**Decision**: Use `plenary.nvim` test harness for plugin unit tests.

**Rationale**:
- De facto standard for Neovim plugin testing
- Provides async support for testing CLI invocation
- Familiar to Neovim plugin developers
- Integrates with CI/CD pipelines

**Alternatives Considered**:
- Minimal custom test harness: Rejected due to reinventing wheel
- Busted (LuaRocks test framework): Rejected due to lack of Neovim-specific APIs

**Impact**: Enables robust plugin testing with mocked CLI responses.

#### AD-003: Store Tokens in File, Config in Keychain

**Decision**: Store OAuth tokens in `~/.outlook-md/token-cache` with 0600 permissions. Store client ID and tenant ID in macOS Keychain.

**Rationale**:
- Tokens require refresh and expiry tracking (file-based cache simpler)
- Client ID and tenant ID are semi-static (Keychain prevents accidental commit)
- File permissions (0600) provide adequate security for tokens
- Keychain integration adds defense-in-depth for credentials

**Alternatives Considered**:
- Store everything in Keychain: Rejected due to complexity of token refresh updates
- Store everything in file: Rejected due to risk of committing plaintext client ID to git

**Impact**: Balances security with implementation simplicity.

#### AD-004: Version JSON Schema, Allow Forward Compatibility

**Decision**: Include `version` field in JSON output. Plugin checks version and rejects unsupported versions. Plugin ignores unknown fields (forward compatible).

**Rationale**:
- Enables CLI evolution without breaking old plugins (additive changes)
- Allows breaking changes to be detected (version mismatch error)
- Follows semantic versioning principles

**Alternatives Considered**:
- No versioning: Rejected due to inability to detect incompatibilities
- Content negotiation (Accept header): Rejected due to CLI simplicity (not HTTP API)

**Impact**: Enables independent CLI and plugin release cycles.

#### AD-005: Atomic Buffer Replacement in Plugin

**Decision**: Plugin builds complete new managed region in memory, then atomically replaces lines between markers using `nvim_buf_set_lines`.

**Rationale**:
- Prevents partial updates on error (Principle VII: Failure Transparency)
- Simplifies rollback on parse/merge errors
- Neovim API supports atomic multi-line replacement

**Alternatives Considered**:
- Line-by-line incremental updates: Rejected due to partial update risk
- Write to temp buffer, swap: Rejected due to complexity with buffer-local state

**Impact**: Ensures Obsidian safety (Principle II) even on error.

#### AD-006: Use Inline Markers (HTML Comments) vs. Heading Boundaries

**Decision**: Use HTML comment markers (`<!-- AGENDA_START -->`) for managed region boundaries.

**Rationale**:
- Invisible in rendered markdown (Obsidian displays rendered view)
- Unambiguous parsing (no confusion with user headings)
- Consistent with existing markdown metadata patterns

**Alternatives Considered**:
- Heading boundaries (e.g., `## Agenda`): Rejected due to ambiguity (user may have headings with same text)
- YAML frontmatter: Rejected due to Obsidian rendering limitations (frontmatter not inline)

**Impact**: Clean user experience in Obsidian while maintaining machine parsability.

## Phase 2: Task Decomposition

**Status**: Not started (handled by `/speckit.tasks` command)

This phase is executed by the `/speckit.tasks` command, which generates `tasks.md` with dependency-ordered, atomically testable tasks.

**Expected Output**: `specs/001-outlook-md-sync/tasks.md`

## Next Steps

1. ✅ Constitution Check passed (all principles satisfied)
2. ⏳ **Phase 0**: Execute research tasks, document findings in `research.md`
3. ⏳ **Phase 1**: Generate design artifacts (`data-model.md`, `contracts/cli-plugin-v1.json`, `quickstart.md`)
4. ⏳ **Phase 1**: Update agent context by running agent context script
5. ⏳ **Post-Design Re-Check**: Verify constitution compliance after design decisions
6. ⬜ **Phase 2**: Run `/speckit.tasks` to generate actionable task breakdown
7. ⬜ **Implementation**: Execute tasks from `tasks.md`

**Current Status**: Ready to proceed with Phase 0 research.