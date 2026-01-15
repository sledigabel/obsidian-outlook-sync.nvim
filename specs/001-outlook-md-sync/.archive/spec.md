# Feature Specification: Outlook Calendar Sync to Obsidian Markdown

**Feature Branch**: `001-outlook-md-sync`
**Created**: 2026-01-07
**Status**: Draft
**Input**: User description: "Outlook calendar sync to Obsidian markdown notes via Go CLI and Neovim plugin"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Initial Calendar Sync (Priority: P1)

As a Neovim user editing Obsidian notes, I want to fetch today's calendar events from my Outlook/M365 calendar and insert them into a managed region of my current note, so that I can see my agenda while taking notes.

**Why this priority**: This is the core MVP functionality. Without the ability to fetch and display calendar events, the entire system has no value. This represents the minimum viable product that delivers immediate value to users.

**Independent Test**: Can be fully tested by running `:OutlookAgendaToday` in Neovim with a markdown file containing `<!-- AGENDA_START -->` and `<!-- AGENDA_END -->` markers, and verifying that calendar events appear between the markers.

**Acceptance Scenarios**:

1. **Given** a markdown file with agenda markers and valid Microsoft Graph credentials, **When** the user runs `:OutlookAgendaToday`, **Then** today's calendar events appear between the markers formatted as markdown with time, subject, and location
2. **Given** the user has no events today, **When** the sync command runs, **Then** the managed region contains no events but markers remain intact
3. **Given** the user has multiple events today, **When** the sync command runs, **Then** all events are rendered in chronological order with correct time formatting (HH:MM–HH:MM)
4. **Given** an event has no location, **When** the sync command runs, **Then** the event renders without parentheses (format: **HH:MM–HH:MM** Subject)

---

### User Story 2 - Preserve User Notes on Refresh (Priority: P1)

As a user who has added meeting notes under calendar events, I want these notes to be preserved when I refresh the agenda, so that I don't lose important information when the calendar updates.

**Why this priority**: This is equally critical as the initial sync because without note preservation, users will lose their work on every refresh, making the tool unusable for its intended purpose. This is part of the core value proposition.

**Independent Test**: Can be fully tested by adding custom content between `<!-- NOTES_START -->` and `<!-- NOTES_END -->` markers under an event, running `:OutlookAgendaToday` again, and verifying the custom content remains unchanged.

**Acceptance Scenarios**:

1. **Given** an existing event with user notes in its notes pocket, **When** the agenda refreshes and the event still exists, **Then** the notes pocket content is preserved verbatim including whitespace and formatting
2. **Given** an event with meaningful notes, **When** the event is deleted from the calendar, **Then** the event is retained with a `[deleted]` marker in the header and notes remain accessible
3. **Given** an event with only scaffold content (auto-generated lines starting with `- <auto>`), **When** the event is deleted from the calendar, **Then** the event is removed entirely from the managed region
4. **Given** multiple events with various note states, **When** refresh occurs, **Then** only the managed region between AGENDA_START/END is updated; all content outside remains untouched

---

### User Story 3 - First-Time Authentication (Priority: P2)

As a new user, I want to authenticate with Microsoft Graph using device-code flow, so that I can grant the CLI access to my calendar without exposing credentials in config files.

**Why this priority**: This is necessary for users to begin using the system, but it's a one-time setup step. After initial authentication, the token cache allows continued use. This can be implemented after the core sync logic is working.

**Independent Test**: Can be fully tested by running `outlook-md today --format json --tz America/New_York` without existing tokens, verifying a device code URL is displayed, completing auth in browser, and confirming the CLI returns calendar events in JSON format.

**Acceptance Scenarios**:

1. **Given** no existing token cache, **When** the user runs the CLI command, **Then** a device code URL and instructions are displayed on stderr
2. **Given** the user completes auth in the browser, **When** the CLI polls for completion, **Then** the token is cached with 0600 permissions and the command succeeds
3. **Given** an expired token in cache, **When** the CLI runs, **Then** the token is automatically refreshed and the command succeeds
4. **Given** an invalid or revoked token, **When** the CLI runs, **Then** a clear error message is displayed on stderr with instructions to re-authenticate

---

### User Story 4 - Attendee Information Display (Priority: P2)

As a meeting participant, I want to see organizer and attendee information for each event, so that I know who is involved and can prepare accordingly.

**Why this priority**: This enhances the value of the calendar display but is not essential for basic agenda viewing. Users can still see meeting times and subjects without attendee information.

**Independent Test**: Can be fully tested by syncing events with various attendee counts and verifying the attendee lists are formatted correctly with deterministic ordering and truncation at 15 attendees.

**Acceptance Scenarios**:

1. **Given** an event with 5 attendees, **When** the event is rendered, **Then** all attendees are listed under the Invitees section with their name, email, and type (required/optional/resource)
2. **Given** an event with 20 attendees, **When** the event is rendered, **Then** the first 15 attendees are shown followed by "…and 5 more (total 20)"
3. **Given** attendees of mixed types, **When** the event is rendered, **Then** they are ordered by: required first, then optional, then resource, then by email (lowercase), then by name (lowercase)
4. **Given** an event with an organizer, **When** the event is rendered, **Then** the organizer appears in the Organizer section with name and email

---

### User Story 5 - Secure Configuration Management (Priority: P3)

As a macOS user, I want to store my Microsoft Graph client ID and tenant ID in Apple Keychain, so that these sensitive values are not stored in plaintext config files.

**Why this priority**: This is a security enhancement that protects against accidental credential exposure. However, the token cache already has restricted permissions (0600), and the client ID/tenant are not as sensitive as tokens themselves. This can be added after core functionality is stable.

**Independent Test**: Can be fully tested by storing credentials in Keychain using the documented `security` commands, removing any plaintext config, and verifying the CLI successfully retrieves values from Keychain.

**Acceptance Scenarios**:

1. **Given** credentials stored in Apple Keychain, **When** the CLI runs, **Then** it successfully retrieves client ID and tenant from Keychain using the defined service name and account keys
2. **Given** missing Keychain entries, **When** the CLI runs, **Then** a clear error message is displayed with instructions to add the required Keychain entries
3. **Given** Keychain access is denied, **When** the CLI runs, **Then** an error message explains the permission issue and suggests granting Keychain access

---

### User Story 6 - Custom Time Range Queries (Priority: P3)

As a user planning ahead, I want to query events for custom date ranges beyond "today", so that I can sync events for upcoming days or specific time windows.

**Why this priority**: This extends the utility of the tool but is not required for the daily agenda use case. Users can get immediate value from the "today" command alone.

**Independent Test**: Can be fully tested by running `outlook-md range 2026-01-08T00:00:00Z 2026-01-10T23:59:59Z --format json --tz America/New_York` and verifying events within that range are returned.

**Acceptance Scenarios**:

1. **Given** a start and end timestamp in RFC3339 format, **When** the range command runs, **Then** all events within that window are returned in JSON format
2. **Given** a multi-day range, **When** the plugin renders events, **Then** events are organized chronologically regardless of date boundaries
3. **Given** a range with no events, **When** the command runs, **Then** an empty events array is returned with exit code 0

---

### Edge Cases

- What happens when an event has no subject (blank or null)?
  - Rendered as **HH:MM–HH:MM** (Untitled Event) with location if available

- How does the system handle all-day events?
  - All-day events are included with isAllDay: true in JSON; plugin renders them without time range as "**All Day**: Subject"

- What happens when the managed region markers are missing or malformed?
  - Plugin displays error message: "AGENDA_START or AGENDA_END marker not found" and does not modify the buffer

- How does the system handle multiple managed regions in one file?
  - Only the first matching pair of AGENDA_START/AGENDA_END is updated; others are ignored

- What happens when an event moves to a different time on refresh?
  - Event is matched by EVENT_ID; notes are preserved, but header time is updated to new time

- How does the system handle events with HTML or special characters in subject/location?
  - All text is rendered as-is in markdown; HTML tags are not interpreted, special characters (*, _, etc.) are preserved

- What happens when the CLI is not found in PATH?
  - Plugin displays error: "outlook-md CLI not found. Please ensure it is installed and in PATH"

- How does the system handle network failures during calendar fetch?
  - CLI returns non-zero exit code with error message on stderr; plugin displays error to user without modifying buffer

- What happens when token refresh fails?
  - CLI returns non-zero exit code with message: "Token refresh failed. Please re-authenticate by running: outlook-md today"

- How does the system handle timezone mismatches?
  - All times are converted to the specified IANA timezone; CLI returns times in RFC3339 format, plugin renders in local HH:MM format

- What happens when a notes pocket exists but its EVENT_ID doesn't match any fetched event?
  - If notes are meaningful, event is kept with `[deleted]` marker; if notes are not meaningful (only scaffold), event is removed

- How does the system handle JSON schema version mismatches?
  - Plugin checks version field; if unsupported version, displays error: "Unsupported CLI output version: N. Please update plugin or CLI"

## Requirements *(mandatory)*

### Functional Requirements

**Go CLI (outlook-md)**:

- **FR-001**: CLI MUST authenticate using Microsoft Graph device-code flow with delegated access permissions
- **FR-002**: CLI MUST support a `today` command that fetches calendar events for 00:00–24:00 in the specified timezone
- **FR-003**: CLI MUST support a `range` command that accepts startRFC3339 and endRFC3339 parameters
- **FR-004**: CLI MUST accept a `--format json` flag and output machine-readable JSON on stdout
- **FR-005**: CLI MUST accept a `--tz` parameter with IANA timezone identifier
- **FR-006**: CLI MUST query the Microsoft Graph `/me/calendarView` endpoint for calendar events
- **FR-007**: CLI MUST cache access tokens on disk with 0600 file permissions
- **FR-008**: CLI MUST support retrieving client ID and tenant ID from Apple Keychain on macOS
- **FR-009**: CLI MUST return exit code 0 on success and non-zero on failure
- **FR-010**: CLI MUST write error messages only to stderr, never to stdout when `--format json` is specified
- **FR-011**: CLI MUST output JSON conforming to the versioned schema with fields: version, timezone, window, events
- **FR-012**: Each event in JSON MUST include: id, subject, isAllDay, start, end, location, organizer {name, email}, attendees [{name, email, type}]
- **FR-013**: CLI MUST NOT perform any markdown parsing, rendering, or merging operations

**Neovim Plugin (outlook_md)**:

- **FR-014**: Plugin MUST provide a `:OutlookAgendaToday` command accessible from any buffer
- **FR-015**: Plugin MUST invoke the Go CLI as a subprocess and capture stdout/stderr
- **FR-016**: Plugin MUST parse the current buffer to locate `<!-- AGENDA_START -->` and `<!-- AGENDA_END -->` markers
- **FR-017**: Plugin MUST validate JSON schema version and required fields; MUST ignore unknown fields for forward compatibility
- **FR-018**: Plugin MUST extract existing events and their notes pockets by parsing `<!-- EVENT_ID: -->`, `<!-- NOTES_START -->`, and `<!-- NOTES_END -->` markers
- **FR-019**: Plugin MUST match events between old and new state using EVENT_ID
- **FR-020**: Plugin MUST preserve content inside `<!-- NOTES_START -->` and `<!-- NOTES_END -->` verbatim, including all whitespace
- **FR-021**: Plugin MUST NOT modify any content outside the `<!-- AGENDA_START -->` to `<!-- AGENDA_END -->` region
- **FR-022**: Plugin MUST render new events (no prior notes pocket) with the scaffold structure: Agenda, Organizer, Invitees, Notes sections
- **FR-023**: Plugin MUST mark deleted events as `[deleted]` in the header if notes are meaningful
- **FR-024**: Plugin MUST remove deleted events entirely if notes are not meaningful
- **FR-025**: Plugin MUST determine "meaningful notes" as: at least one line that is not blank, not a section header, not scaffold, and not starting with `- <auto>`
- **FR-026**: Plugin MUST render attendees in deterministic order: required, optional, resource, then by email (lowercase), then by name (lowercase)
- **FR-027**: Plugin MUST truncate attendee lists at 15 entries and append "…and N more (total T)" if attendees > 15
- **FR-028**: Plugin MUST support configurable marker strings for AGENDA_START/AGENDA_END
- **FR-029**: Plugin MUST display CLI error messages to the user if CLI returns non-zero exit code
- **FR-030**: Plugin MUST format event times as HH:MM–HH:MM in the timezone specified to the CLI

**Event Rendering Format**:

- **FR-031**: Each event MUST be rendered with header: `- **HH:MM–HH:MM** Subject (Location)` or `- **HH:MM–HH:MM** Subject` if no location
- **FR-032**: All-day events MUST be rendered as: `- **All Day**: Subject (Location)`
- **FR-033**: Event header for deleted events MUST include `[deleted]` tag: `- **HH:MM–HH:MM** Subject (Location) [deleted]`
- **FR-034**: New event scaffold MUST include sections: Agenda, Organizer, Invitees, Notes
- **FR-035**: Auto-generated lines MUST be prefixed with `- <auto>` for identification
- **FR-036**: Organizer MUST be rendered as: `- <auto> Name <email>`
- **FR-037**: Invitees MUST be rendered as: `- <auto> Name <email> (required|optional|resource)`
- **FR-038**: Invitee truncation summary MUST be rendered as: `- <auto> …and N more (total T)`

**Security Requirements**:

- **FR-039**: Token cache file MUST have 0600 permissions (owner read/write only)
- **FR-040**: CLI MUST support Apple Keychain storage for client ID with service name and account key
- **FR-041**: CLI MUST support Apple Keychain storage for tenant ID with service name and account key
- **FR-042**: CLI MUST NOT log or display access tokens in any output
- **FR-043**: CLI MUST use HTTPS for all Microsoft Graph API calls

**Build & Testing Requirements**:

- **FR-044**: Repository MUST include a Makefile with `make test` target that runs Go unit tests
- **FR-045**: Repository MUST include a Makefile with `make build` target that compiles Go binary to `./bin/` directory
- **FR-046**: Build output directory (`./bin/`) MUST be listed in `.gitignore`
- **FR-047**: Unit tests MUST cover managed region parsing
- **FR-048**: Unit tests MUST cover notes pocket extraction
- **FR-049**: Unit tests MUST cover meaningful-notes detection logic
- **FR-050**: Unit tests MUST cover merge logic including deleted event handling
- **FR-051**: Unit tests MUST cover deterministic rendering and attendee truncation
- **FR-052**: Unit tests MUST cover JSON schema validation
- **FR-053**: Microsoft Graph API interactions MUST be mockable for testing
- **FR-054**: Test suite MUST include at least one mocked integration test of CLI with Graph API

**Documentation Requirements**:

- **FR-055**: README MUST document Microsoft Graph/Entra application setup steps
- **FR-056**: README MUST list required Microsoft Graph API scopes (Calendars.Read minimum)
- **FR-057**: README MUST explain device-code authentication flow and user experience
- **FR-058**: README MUST provide Apple Keychain setup commands using `security` CLI
- **FR-059**: README MUST document token cache location (e.g., `~/.outlook-md/token-cache`)
- **FR-060**: README MUST document commands to clear token cache
- **FR-061**: README MUST include Lazy.nvim plugin spec snippet for installation
- **FR-062**: README MUST document plugin configuration options (at minimum: marker customization)
- **FR-063**: README MUST document `:OutlookAgendaToday` command usage
- **FR-064**: README MUST provide example Obsidian note showing agenda marker structure and rendered events

### Key Entities

- **Calendar Event**: Represents a single event from Microsoft Graph with attributes: unique identifier, subject, all-day flag, start time, end time, location, organizer (name/email), attendees list
- **Organizer**: Person who created the event with attributes: display name, email address
- **Attendee**: Person invited to event with attributes: display name, email address, type (required/optional/resource)
- **Managed Region**: Section of markdown file bounded by start and end markers, containing zero or more rendered events
- **Notes Pocket**: User-editable content area within a rendered event, bounded by notes start and end markers, preserved across refreshes
- **Token Cache**: Persisted OAuth2 access and refresh tokens for Microsoft Graph API access
- **Keychain Entry**: macOS Keychain item containing sensitive configuration (client ID or tenant ID) identified by service name and account key

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can see their day's calendar events in their Obsidian note within 10 seconds of running `:OutlookAgendaToday`
- **SC-002**: Notes added by users to event pockets are preserved across 100% of refreshes when events still exist in calendar
- **SC-003**: Users complete first-time authentication and successfully sync calendar within 5 minutes following README instructions
- **SC-004**: Deleted events with meaningful notes are retained 100% of the time; deleted events without meaningful notes are removed 100% of the time
- **SC-005**: Event rendering is deterministic: same calendar state always produces identical markdown output byte-for-byte
- **SC-006**: Plugin processes and renders 50 calendar events in under 2 seconds on typical hardware
- **SC-007**: Token refresh happens automatically without user intervention for 99% of CLI invocations after initial auth
- **SC-008**: Unit test suite covers 100% of merge logic, meaningful-notes detection, and attendee ordering code paths
- **SC-009**: CLI returns valid JSON conforming to schema for 100% of successful responses
- **SC-010**: Content outside managed region is never modified: byte-identical before and after sync for 100% of refreshes

## Assumptions & Dependencies

### Assumptions

1. Users have an active Microsoft 365 or Outlook.com account with calendar access
2. Users have Go compiler installed for building the CLI (or will use pre-built binaries)
3. Users are running Neovim with Lua support (Neovim 0.5+)
4. Users are editing markdown files in Neovim (not other editors)
5. Users manually insert the AGENDA_START/AGENDA_END markers in their notes before first sync
6. Users' system timezone configuration is accurate if they want times displayed in local time
7. Users have network connectivity to Microsoft Graph APIs (graph.microsoft.com)
8. Users on macOS have Apple Keychain available and accessible
9. Users have registered an Azure AD application with appropriate redirect URIs for device-code flow
10. Users accept that calendar writes are out of scope; this is a read-only sync

### Dependencies

1. **Microsoft Graph API**: Requires Microsoft Graph API availability and `/me/calendarView` endpoint access
2. **OAuth 2.0 Device Code Flow**: Requires Azure AD support for device authorization grant
3. **Go Standard Library**: CLI depends on Go net/http, encoding/json, os, time packages
4. **Neovim Lua API**: Plugin depends on Neovim's vim.fn.system(), buffer APIs, command registration
5. **macOS Security Framework** (macOS only): Keychain integration depends on `security` command-line tool
6. **Lazy.nvim** (recommended): Documentation assumes Lazy.nvim for plugin installation, though other plugin managers should work

### External Constraints

1. **Microsoft Graph API Rate Limits**: Calls to Graph API are subject to Microsoft's rate limiting policies
2. **Token Expiration**: Access tokens typically expire after 1 hour; refresh tokens may expire after inactivity
3. **Azure AD Application Approval**: Some organizations require admin consent for calendar access permissions
4. **Neovim Version**: Plugin requires Neovim 0.5+ for Lua support; will not work with Vim or older Neovim versions

### Defaults & Configuration

- **Default Markers**: `<!-- AGENDA_START -->` and `<!-- AGENDA_END -->` (configurable in plugin)
- **Default Timezone**: If not specified, CLI should use system timezone; plugin should pass user's configured timezone
- **Token Cache Location**: Default to `~/.outlook-md/token-cache` (can be made configurable via environment variable)
- **Keychain Service Name**: `com.github.obsidian-outlook-sync` (fixed)
- **Keychain Account Keys**: `client-id` and `tenant-id` (fixed)
- **Required Graph Scopes**: `Calendars.Read` (minimum); `User.Read` for user profile (standard)
- **Attendee Display Limit**: 15 attendees before truncation (fixed)
- **CLI Timeout**: Plugin should timeout CLI subprocess after 30 seconds
- **Event Subject Fallback**: "(Untitled Event)" when subject is null or empty
- **All-Day Event Display**: "**All Day**: Subject (Location)" format

## Threat Model & Security Considerations

### Assets to Protect

1. **OAuth Access Tokens**: Grant access to user's calendar data
2. **OAuth Refresh Tokens**: Allow long-term access without re-authentication
3. **Client ID & Tenant ID**: Identify the Azure AD application (low sensitivity but should not be in plaintext)
4. **Calendar Event Data**: User's meeting details, attendees, locations (PII)

### Threats & Mitigations

| Threat | Impact | Mitigation | Residual Risk |
|--------|--------|------------|---------------|
| Token file read by other users | High - unauthorized calendar access | Token cache file stored with 0600 permissions (FR-039) | Low - requires attacker to gain access to user's account |
| Token file exposed in git repository | High - credential leak to remote attackers | User must ensure token cache directory is in .gitignore; document this in README | Medium - depends on user configuration |
| Client ID/Tenant exposed in config files | Low - enables API calls but not user access | Store in Apple Keychain on macOS (FR-040, FR-041) | Low - fallback to config files acceptable on other platforms |
| Man-in-the-middle attack on Graph API | High - token interception | Enforce HTTPS for all Graph API calls (FR-043) | Very Low - requires compromising certificate chain |
| Malicious plugin reads token cache | High - any plugin could access tokens | No direct mitigation - user must trust installed plugins | Medium - inherent to plugin architecture |
| Token theft via process inspection | Medium - attacker with system access could read process memory | Keep tokens in memory only during API calls; clear after use | Low - requires attacker to already have significant access |
| Accidental exposure of tokens in logs | Medium - tokens in log files readable by others | Never log or display access tokens (FR-042) | Very Low - assuming code review |
| OAuth refresh token expiry | Low - user inconvenience, not security risk | Display clear re-auth instructions on refresh failure | None - by design |
| Unauthorized Azure AD app registration | Medium - attacker could create malicious app | Document legitimate app ID in README; users verify during setup | Medium - depends on user vigilance |
| Modified CLI binary | High - malicious CLI could exfiltrate data | No direct mitigation - user must build from source or verify binary signature | Medium - supply chain security is user's responsibility |

### Security Principles

1. **Principle of Least Privilege**: Request only `Calendars.Read` scope, not `Calendars.ReadWrite`
2. **Defense in Depth**: Multiple layers: file permissions, HTTPS, token expiry, Keychain storage
3. **Fail Secure**: CLI returns non-zero and clear error if any security check fails (permissions, HTTPS)
4. **Minimize Attack Surface**: CLI has no network server, no IPC beyond stdin/stdout/stderr
5. **Transparency**: Token cache location and security model documented in README
6. **Secure Defaults**: File permissions set to 0600 by default, HTTPS enforced, no token logging

### Compliance Considerations

- **GDPR/Privacy**: Calendar data is personal information; plugin processes it locally without external transmission (except to Microsoft Graph). Users must ensure their Azure AD app registration complies with organizational policies.
- **Data Retention**: Calendar events are fetched on-demand, not stored long-term by CLI. Markdown files containing events are user-managed; users responsible for their own retention policies.

## Out of Scope

The following are explicitly excluded from this specification:

1. **Writing Calendar Events**: No support for creating, modifying, or deleting calendar events via the CLI or plugin
2. **Multi-Calendar Selection**: Only the user's default/primary calendar is accessed; no support for selecting from multiple calendars
3. **Background Sync or Daemons**: No automatic polling or background refresh; user must manually run `:OutlookAgendaToday` to update
4. **Notification or Reminders**: No integration with system notifications or event reminders
5. **Cross-Platform Keychain**: Apple Keychain integration is macOS-only; other platforms will use alternative config methods
6. **Event Attendee Responses**: No display of accept/decline/tentative status for attendees
7. **Recurring Event Expansion**: Microsoft Graph API handles recurrence expansion; CLI/plugin does not need special logic
8. **Attachment or Meeting Notes Access**: No access to file attachments or OneNote meeting notes associated with events
9. **Free/Busy Status**: No display of free/busy/tentative status beyond what's implicit in the event list
10. **Team or Resource Calendars**: Only personal calendar access; no support for shared, team, or room calendars
11. **Offline Mode**: Requires network access to Microsoft Graph; no offline caching of calendar data beyond current refresh
12. **Event Search or Filtering**: No filtering by attendee, subject, location, etc.; all events in time window are synced
13. **Alternative Authentication Methods**: Only device-code flow supported; no interactive browser, client credentials, or certificate-based auth
14. **Plugin Auto-Update**: Plugin and CLI versions managed manually by user; no auto-update mechanism
15. **Multi-Buffer Operations**: Plugin operates only on current buffer; no batch updates across multiple files

## CLI-Plugin Contract

### Command Interface

**Today Command**:
```bash
outlook-md today --format json --tz <IANA_TIMEZONE>
```

**Range Command**:
```bash
outlook-md range <startRFC3339> <endRFC3339> --format json --tz <IANA_TIMEZONE>
```

### Parameters

- `--format`: Output format; only `json` is supported in initial version
- `--tz`: IANA timezone identifier (e.g., `America/New_York`, `Europe/Paris`, `UTC`)
- `<startRFC3339>`: Range start time in RFC3339 format (e.g., `2026-01-07T00:00:00Z`)
- `<endRFC3339>`: Range end time in RFC3339 format (e.g., `2026-01-07T23:59:59Z`)

### Output Channels

- **stdout**: JSON output when `--format json` is specified; otherwise may be human-readable (future)
- **stderr**: Error messages, warnings, authentication instructions, device-code URLs
- **Exit codes**:
  - `0`: Success
  - Non-zero: Failure (specific codes may be defined in future versions)

### JSON Schema (Version 1)

```json
{
  "version": 1,
  "timezone": "<IANA_TIMEZONE>",
  "window": {
    "start": "<RFC3339_TIMESTAMP>",
    "end": "<RFC3339_TIMESTAMP>"
  },
  "events": [
    {
      "id": "<string>",
      "subject": "<string>",
      "isAllDay": <boolean>,
      "start": "<RFC3339_TIMESTAMP>",
      "end": "<RFC3339_TIMESTAMP>",
      "location": "<string>",
      "organizer": {
        "name": "<string>",
        "email": "<string>"
      },
      "attendees": [
        {
          "name": "<string>",
          "email": "<string>",
          "type": "<required|optional|resource>"
        }
      ]
    }
  ]
}
```

### Field Specifications

- **version**: Integer schema version (currently 1); plugin MUST validate and reject unsupported versions
- **timezone**: IANA timezone identifier matching the `--tz` parameter
- **window.start**: RFC3339 timestamp of query start (inclusive)
- **window.end**: RFC3339 timestamp of query end (exclusive)
- **events**: Array of event objects (may be empty)
- **event.id**: Unique Microsoft Graph event identifier (used for matching across refreshes)
- **event.subject**: Event title/subject (may be empty string, never null)
- **event.isAllDay**: Boolean indicating all-day event
- **event.start**: RFC3339 timestamp of event start in specified timezone
- **event.end**: RFC3339 timestamp of event end in specified timezone
- **event.location**: Location string (may be empty, never null)
- **event.organizer**: Object with `name` and `email` (both strings, may be empty but never null)
- **event.attendees**: Array of attendee objects (may be empty); each has `name`, `email`, `type`
- **attendee.type**: One of: `required`, `optional`, `resource`

### Contract Requirements

- Plugin MUST check `version` field and fail gracefully if version is unsupported
- Plugin MUST handle unknown fields by ignoring them (forward compatibility)
- Plugin MUST treat missing optional fields as empty strings or empty arrays
- CLI MUST ensure all required fields are present in output
- CLI MUST escape any special characters in JSON strings according to JSON spec
- CLI MUST output valid, parseable JSON to stdout when `--format json` is used
- CLI MUST return non-zero exit code if authentication, API call, or JSON serialization fails
- Plugin MUST capture stderr separately and display it to user if CLI returns non-zero exit code

### Error Handling

- **Authentication failure**: CLI returns non-zero, stderr contains device-code URL or re-auth instructions
- **Network failure**: CLI returns non-zero, stderr contains: "Failed to connect to Microsoft Graph: <error>"
- **API error**: CLI returns non-zero, stderr contains: "Microsoft Graph API error: <code> <message>"
- **Invalid parameters**: CLI returns non-zero, stderr contains usage instructions
- **Token expired and refresh failed**: CLI returns non-zero, stderr contains: "Token refresh failed. Please re-authenticate by running: outlook-md today"

### Versioning Strategy

- **Schema version** in JSON output allows plugin to detect incompatible CLI versions
- **Forward compatibility**: Plugin ignores unknown fields, allowing CLI to add fields in same schema version
- **Breaking changes**: CLI increments `version` number; plugin must explicitly support new version
- **Recommended practice**: Plugin should warn user if CLI version is much newer than plugin expects