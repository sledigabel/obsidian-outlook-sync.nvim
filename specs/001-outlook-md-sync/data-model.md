# Data Model: Outlook Calendar Sync

**Feature**: Outlook Calendar Sync to Obsidian Markdown
**Branch**: 001-outlook-md-sync
**Date**: 2026-01-07

## Overview

This document defines the core data entities, their relationships, validation rules, and operations for the Outlook calendar sync feature. The data model is split across two components (CLI and plugin) with a JSON contract serving as the boundary.

## CLI Component Data Model (Go)

### CalendarEvent

Represents a single event retrieved from Microsoft Graph API.

**Fields**:
- `id` (string): Unique Microsoft Graph event identifier (e.g., "AAMkAGI2...==")
- `subject` (string): Event title/subject (may be empty string)
- `isAllDay` (boolean): True if event spans entire day(s) without specific times
- `start` (RFC3339 string): Event start timestamp in ISO 8601 format with timezone
- `end` (RFC3339 string): Event end timestamp in ISO 8601 format with timezone
- `location` (string): Event location/room (may be empty string)
- `organizer` (Organizer): Event organizer details
- `attendees` ([]Attendee): List of event attendees (may be empty array)

**Validation Rules**:
- `id` must be non-empty
- `start` must be parsable as RFC3339 timestamp
- `end` must be parsable as RFC3339 timestamp
- `end` must be after `start` (for non-all-day events)
- `attendees` must be sorted deterministically (see Attendee sorting rules)

**State**: Immutable value object (once created from Graph API response, never modified)

**Operations**:
- `FromGraphEvent(graphEvent)`: Convert Microsoft Graph API response to CalendarEvent
- `SortAttendees()`: Apply deterministic ordering to attendees list
- `ToJSON()`: Serialize to JSON according to CLI output schema v1

**Example**:
```json
{
  "id": "AAMkAGI2THVSAAA=",
  "subject": "Team Standup",
  "isAllDay": false,
  "start": "2026-01-07T09:00:00-05:00",
  "end": "2026-01-07T09:30:00-05:00",
  "location": "Conference Room A",
  "organizer": {
    "name": "Alice Smith",
    "email": "alice@example.com"
  },
  "attendees": [
    {"name": "Bob Jones", "email": "bob@example.com", "type": "required"},
    {"name": "Carol White", "email": "carol@example.com", "type": "optional"}
  ]
}
```

---

### Organizer

Represents the event organizer (person who created/owns the event).

**Fields**:
- `name` (string): Organizer display name (may be empty)
- `email` (string): Organizer email address (may be empty)

**Validation Rules**:
- No strict email format validation (informational only)
- Both fields may be empty if Graph API returns null

**State**: Immutable value object

**Operations**:
- `FromGraphOrganizer(graphOrganizer)`: Convert from Graph API response

**Example**:
```json
{
  "name": "Alice Smith",
  "email": "alice@example.com"
}
```

---

### Attendee

Represents a single attendee invited to the event.

**Fields**:
- `name` (string): Attendee display name (may be empty)
- `email` (string): Attendee email address (may be empty)
- `type` (enum string): Attendee type, one of: "required", "optional", "resource"

**Validation Rules**:
- `type` must be exactly one of: "required", "optional", "resource" (lowercase)
- Invalid types should default to "optional" with warning logged

**Ordering Rules** (deterministic sort):
1. Primary sort: Type (required < optional < resource)
2. Secondary sort: Email address (case-insensitive ASCII comparison, lowercase)
3. Tertiary sort: Name (case-insensitive ASCII comparison, lowercase)

**State**: Immutable value object

**Operations**:
- `FromGraphAttendee(graphAttendee)`: Convert from Graph API response
- `Compare(other Attendee) int`: Comparison function for sorting (-1, 0, +1)

**Example**:
```json
{
  "name": "Bob Jones",
  "email": "bob@example.com",
  "type": "required"
}
```

**Sorting Example**:
Given attendees: [Carol (optional, carol@), Alice (required, alice@), Bob (required, bob@)]
Sorted result: [Alice (required, alice@), Bob (required, bob@), Carol (optional, carol@)]

---

### CLIOutput (JSON Schema v1)

Represents the complete output from the CLI, sent to plugin via stdout.

**Fields**:
- `version` (integer): Schema version, must be 1
- `timezone` (string): IANA timezone identifier (e.g., "America/New_York")
- `window` (TimeWindow): Query time range
- `events` ([]CalendarEvent): Array of events (may be empty)

**Validation Rules**:
- `version` must equal 1 (CLI responsibility)
- `timezone` must be valid IANA timezone string
- `window.start` must be before `window.end`
- `events` must be present (null not allowed, empty array OK)

**State**: Immutable (generated once per CLI invocation)

**Operations**:
- `NewCLIOutput(timezone, window, events) CLIOutput`: Constructor
- `Validate() error`: Validate schema compliance
- `ToJSON() ([]byte, error)`: Serialize to JSON

**Example**:
```json
{
  "version": 1,
  "timezone": "America/New_York",
  "window": {
    "start": "2026-01-07T00:00:00-05:00",
    "end": "2026-01-08T00:00:00-05:00"
  },
  "events": [...]
}
```

---

### TimeWindow

Represents the query time range for calendar events.

**Fields**:
- `start` (RFC3339 string): Range start (inclusive)
- `end` (RFC3339 string): Range end (exclusive)

**Validation Rules**:
- Both must be valid RFC3339 timestamps
- `start` must be before `end`

**State**: Immutable value object

---

## Plugin Component Data Model (Lua)

### ManagedRegion

Represents the parsed state of the agenda block within a markdown buffer.

**Fields**:
- `start_line` (integer): 1-indexed line number of AGENDA_START marker
- `end_line` (integer): 1-indexed line number of AGENDA_END marker
- `events` (table of ParsedEvent): Existing events extracted from buffer
- `content_outside` (string): All buffer content outside managed region (read-only reference)

**Validation Rules**:
- `start_line` must be < `end_line`
- Both markers must exist in buffer
- Only one pair of markers allowed (first pair used, others ignored)

**State**: Mutable during merge operation, then replaced atomically

**Operations**:
- `parse_buffer(buffer_lines) -> ManagedRegion | error`: Extract managed region from buffer lines
- `extract_events() -> table of ParsedEvent`: Parse existing events within region
- `build_new_region(new_events) -> table of lines`: Generate replacement lines for managed region
- `replace_in_buffer(buffer_handle) -> success, error`: Atomically replace lines in Neovim buffer

**Example**:
```lua
{
  start_line = 15,
  end_line = 42,
  events = {
    {event_id = "AAMkAGI...", notes_pocket = "- My notes here\n", ...},
    ...
  }
}
```

---

### ParsedEvent

Represents an event that already exists in the markdown buffer (from previous sync).

**Fields**:
- `event_id` (string): Microsoft Graph event ID (extracted from EVENT_ID marker)
- `header` (string): Original event header line (e.g., "- **09:00–09:30** Team Standup")
- `notes_pocket` (string): Content between NOTES_START and NOTES_END markers (verbatim)
- `is_deleted` (boolean): True if header contains "[deleted]" marker
- `has_meaningful_notes` (boolean): Cached result of meaningful notes detection

**Validation Rules**:
- `event_id` must be non-empty
- `event_id` must match an EVENT_ID comment marker in buffer

**State**: Immutable once parsed

**Operations**:
- `parse_from_lines(lines) -> ParsedEvent`: Extract event from markdown lines
- `detect_meaningful_notes(notes_pocket) -> boolean`: Apply meaningful notes algorithm
- `merge_with_cli_event(cli_event) -> RenderedEvent`: Combine parsed notes with new event data

**Meaningful Notes Algorithm**:

A notes pocket contains "meaningful" content if **at least one line** is:
- Not blank (not empty and not only whitespace)
- Not a section header (not matching `^- Agenda:$`, `^- Organizer:$`, `^- Invitees:$`, `^- Notes:$`)
- Not scaffold (not starting with `- <auto>`)

**Example**:
```lua
{
  event_id = "AAMkAGI2THVSAAA=",
  header = "- **09:00–09:30** Team Standup (Conference Room A)",
  notes_pocket = "- Agenda:\n  - <auto> **09:00–09:30** Team Standup\n- My action items:\n  - Follow up with Bob\n",
  is_deleted = false,
  has_meaningful_notes = true  -- "- Follow up with Bob" is meaningful
}
```

---

### RenderedEvent

Represents an event ready to be written to the buffer (either new or merged).

**Fields**:
- `event_id` (string): Microsoft Graph event ID
- `header` (string): Generated header line
- `scaffold` (table of strings): Generated scaffold lines (Agenda, Organizer, Invitees)
- `notes_pocket` (string): Preserved user notes or empty scaffold
- `sort_key` (string): RFC3339 start time for chronological sorting

**Validation Rules**:
- `event_id` must be non-empty
- `header` must follow format spec (FR-031 to FR-033)
- `notes_pocket` must be enclosed in NOTES_START/NOTES_END markers

**State**: Immutable once generated

**Operations**:
- `from_cli_event(cli_event) -> RenderedEvent`: Create new event without prior notes
- `from_merged(cli_event, parsed_event) -> RenderedEvent`: Merge CLI event with existing notes
- `from_deleted(parsed_event) -> RenderedEvent`: Mark event as deleted, preserve notes
- `to_lines() -> table of strings`: Convert to markdown lines for buffer insertion

**Example**:
```lua
{
  event_id = "AAMkAGI2THVSAAA=",
  header = "- **09:00–09:30** Team Standup (Conference Room A)",
  scaffold = {
    "- Agenda:",
    "  - <auto> **09:00–09:30** Team Standup",
    "- Organizer:",
    "  - <auto> Alice Smith <alice@example.com>",
    ...
  },
  notes_pocket = "- My notes\n",
  sort_key = "2026-01-07T09:00:00-05:00"
}
```

---

## Data Flow

### 1. CLI Data Flow

```
Microsoft Graph API Response
  ↓
FromGraphEvent() conversion
  ↓
CalendarEvent (unsorted attendees)
  ↓
SortAttendees() deterministic ordering
  ↓
CalendarEvent (sorted)
  ↓
ToJSON() serialization
  ↓
CLIOutput JSON → stdout
```

### 2. Plugin Data Flow

```
Buffer lines
  ↓
ManagedRegion.parse_buffer()
  ↓
Extract ParsedEvents from existing region
  ↓
CLI subprocess invocation
  ↓
Parse JSON from CLI stdout
  ↓
For each CLI event:
  - Match by event_id to ParsedEvent
  - If match: merge (preserve notes)
  - If no match: create new RenderedEvent
  ↓
For each ParsedEvent not in CLI:
  - If meaningful notes: mark [deleted], keep
  - If not meaningful: discard
  ↓
Sort RenderedEvents by sort_key (chronological)
  ↓
Generate markdown lines for each RenderedEvent
  ↓
Atomically replace managed region in buffer
```

## Relationships

```
CLIOutput (1) ──has──> (0..N) CalendarEvent
CalendarEvent (1) ──has──> (1) Organizer
CalendarEvent (1) ──has──> (0..N) Attendee

ManagedRegion (1) ──contains──> (0..N) ParsedEvent
ParsedEvent (0..1) ──merges with──> (0..1) CalendarEvent ──produces──> (1) RenderedEvent
```

## Invariants

1. **Determinism**: Given identical `CLIOutput` and `ManagedRegion` state, `build_new_region()` always produces identical output (byte-for-byte)

2. **Obsidian Safety**: `replace_in_buffer()` only modifies lines between `start_line` and `end_line` (inclusive)

3. **Notes Preservation**: For events with matching `event_id`, `notes_pocket` from `ParsedEvent` is byte-identical in resulting `RenderedEvent`

4. **Atomicity**: `replace_in_buffer()` either succeeds completely or fails with no buffer modification (no partial updates)

5. **Attendee Ordering**: `CalendarEvent.attendees` array is always sorted according to deterministic rules

6. **JSON Schema Compliance**: `CLIOutput.ToJSON()` always produces valid JSON conforming to schema v1

## Edge Cases

### Empty Events Array

**Scenario**: No events in time window
**Behavior**: `CLIOutput.events` is empty array `[]`, not null
**Plugin Action**: Managed region contains only markers, no event lines

### Missing Subject

**Scenario**: Event has empty or null subject
**Behavior**: Render as "(Untitled Event)" in header

### Missing Location

**Scenario**: Event has empty or null location
**Behavior**: Omit parentheses from header: "**HH:MM–HH:MM** Subject"

### All-Day Event

**Scenario**: `isAllDay` is true
**Behavior**: Render header as "**All Day**: Subject (Location)"

### Event with 0 Attendees

**Scenario**: `attendees` array is empty
**Behavior**: Invitees section shows "(No attendees)"

### Event with > 15 Attendees

**Scenario**: `attendees.length > 15`
**Behavior**: Render first 15, append "- <auto> …and N more (total T)"

### Deleted Event with Meaningful Notes

**Scenario**: Event not in CLI output, ParsedEvent has meaningful notes
**Behavior**: Retain event with "[deleted]" in header, preserve notes pocket

### Deleted Event without Meaningful Notes

**Scenario**: Event not in CLI output, ParsedEvent has only scaffold
**Behavior**: Discard event entirely, do not render

### Multiple Managed Regions

**Scenario**: Buffer has multiple AGENDA_START/AGENDA_END pairs
**Behavior**: Only update first pair, ignore others

## Testing Considerations

### Unit Test Coverage

1. **Attendee Sorting**: Verify deterministic ordering with edge cases (same email, same name, all types)
2. **Meaningful Notes Detection**: Test boundary cases (blank lines, only headers, mixed content)
3. **JSON Schema Validation**: Ensure all required fields present, version correct
4. **Header Rendering**: Verify format for all edge cases (no location, all-day, deleted)
5. **Atomic Buffer Replacement**: Simulate failures, ensure no partial updates

### Integration Test Scenarios

1. **First Sync**: Empty buffer → multiple events rendered
2. **Refresh with Notes**: Events with user notes → notes preserved
3. **Event Moved**: Event time changes → header updated, notes preserved
4. **Event Deleted**: Event removed from calendar → marked deleted or discarded
5. **New Event Added**: New event appears → scaffold inserted without affecting existing events

### Property-Based Testing

1. **Determinism**: Same inputs always produce same output (compare hashes)
2. **Idempotence**: Sync twice with same data → buffer unchanged on second sync
3. **Notes Safety**: Content outside managed region never modified (compare before/after)

## References

- Specification: [spec.md](./spec.md)
- Implementation Plan: [plan.md](./plan.md)
- CLI-Plugin Contract: [contracts/cli-plugin-v1.json](./contracts/cli-plugin-v1.json)