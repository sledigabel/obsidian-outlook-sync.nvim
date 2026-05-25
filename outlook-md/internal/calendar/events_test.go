package calendar

import (
	"testing"
	"time"

	"github.com/obsidian-outlook-sync/outlook-md/pkg/schema"
)

// TestSortAttendees verifies deterministic multi-key attendee sorting
// per FR-026: Sort by type (required < optional < resource), then email, then name
func TestSortAttendees(t *testing.T) {
	tests := []struct {
		name     string
		input    []schema.Attendee
		expected []schema.Attendee
	}{
		{
			name: "sort by type (required first)",
			input: []schema.Attendee{
				{Name: "Resource Room", Email: "room@example.com", Type: "resource"},
				{Name: "Optional User", Email: "optional@example.com", Type: "optional"},
				{Name: "Required User", Email: "required@example.com", Type: "required"},
			},
			expected: []schema.Attendee{
				{Name: "Required User", Email: "required@example.com", Type: "required"},
				{Name: "Optional User", Email: "optional@example.com", Type: "optional"},
				{Name: "Resource Room", Email: "room@example.com", Type: "resource"},
			},
		},
		{
			name: "sort by email within same type (case-insensitive)",
			input: []schema.Attendee{
				{Name: "User C", Email: "charlie@example.com", Type: "required"},
				{Name: "User A", Email: "Alice@example.com", Type: "required"},
				{Name: "User B", Email: "bob@example.com", Type: "required"},
			},
			expected: []schema.Attendee{
				{Name: "User A", Email: "Alice@example.com", Type: "required"},
				{Name: "User B", Email: "bob@example.com", Type: "required"},
				{Name: "User C", Email: "charlie@example.com", Type: "required"},
			},
		},
		{
			name: "sort by name when type and email match",
			input: []schema.Attendee{
				{Name: "Zoe Smith", Email: "shared@example.com", Type: "required"},
				{Name: "Alice Jones", Email: "shared@example.com", Type: "required"},
				{Name: "Bob Wilson", Email: "shared@example.com", Type: "required"},
			},
			expected: []schema.Attendee{
				{Name: "Alice Jones", Email: "shared@example.com", Type: "required"},
				{Name: "Bob Wilson", Email: "shared@example.com", Type: "required"},
				{Name: "Zoe Smith", Email: "shared@example.com", Type: "required"},
			},
		},
		{
			name: "complex multi-key sort",
			input: []schema.Attendee{
				{Name: "Room 1", Email: "room1@example.com", Type: "resource"},
				{Name: "Optional B", Email: "b@example.com", Type: "optional"},
				{Name: "Required C", Email: "c@example.com", Type: "required"},
				{Name: "Optional A", Email: "a@example.com", Type: "optional"},
				{Name: "Required A", Email: "a@example.com", Type: "required"},
				{Name: "Required B", Email: "b@example.com", Type: "required"},
			},
			expected: []schema.Attendee{
				{Name: "Required A", Email: "a@example.com", Type: "required"},
				{Name: "Required B", Email: "b@example.com", Type: "required"},
				{Name: "Required C", Email: "c@example.com", Type: "required"},
				{Name: "Optional A", Email: "a@example.com", Type: "optional"},
				{Name: "Optional B", Email: "b@example.com", Type: "optional"},
				{Name: "Room 1", Email: "room1@example.com", Type: "resource"},
			},
		},
		{
			name: "stable sort - preserve order for identical elements",
			input: []schema.Attendee{
				{Name: "User A", Email: "user@example.com", Type: "required"},
				{Name: "User A", Email: "user@example.com", Type: "required"},
				{Name: "User A", Email: "user@example.com", Type: "required"},
			},
			expected: []schema.Attendee{
				{Name: "User A", Email: "user@example.com", Type: "required"},
				{Name: "User A", Email: "user@example.com", Type: "required"},
				{Name: "User A", Email: "user@example.com", Type: "required"},
			},
		},
		{
			name:     "empty list",
			input:    []schema.Attendee{},
			expected: []schema.Attendee{},
		},
		{
			name: "single attendee",
			input: []schema.Attendee{
				{Name: "Solo User", Email: "solo@example.com", Type: "required"},
			},
			expected: []schema.Attendee{
				{Name: "Solo User", Email: "solo@example.com", Type: "required"},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Make a copy to avoid modifying test data
			attendees := make([]schema.Attendee, len(tt.input))
			copy(attendees, tt.input)

			// Sort attendees
			sortAttendees(attendees)

			// Verify result matches expected
			if len(attendees) != len(tt.expected) {
				t.Fatalf("length mismatch: got %d, want %d", len(attendees), len(tt.expected))
			}

			for i := range attendees {
				if attendees[i] != tt.expected[i] {
					t.Errorf("attendee[%d] mismatch:\ngot:  %+v\nwant: %+v",
						i, attendees[i], tt.expected[i])
				}
			}
		})
	}
}

// TestParseCalendarEventsTimestamps verifies StartUnix and EndUnix are populated
// correctly, including non-UTC timezones (America/New_York).
func TestParseCalendarEventsTimestamps(t *testing.T) {
	// "2026-05-25T09:00:00" in America/New_York = 13:00 UTC = Unix 1748178000
	// "2026-05-25T10:00:00" in America/New_York = 14:00 UTC = Unix 1748181600
	events := []graphEvent{
		{
			ID:      "TEST-001",
			Subject: "Morning Standup",
			Start: struct {
				DateTime string `json:"dateTime"`
				TimeZone string `json:"timeZone"`
			}{DateTime: "2026-05-25T09:00:00", TimeZone: "America/New_York"},
			End: struct {
				DateTime string `json:"dateTime"`
				TimeZone string `json:"timeZone"`
			}{DateTime: "2026-05-25T10:00:00", TimeZone: "America/New_York"},
			Attendees: []struct {
				EmailAddress struct {
					Name    string `json:"name"`
					Address string `json:"address"`
				} `json:"emailAddress"`
				Type string `json:"type"`
			}{
				{
					EmailAddress: struct {
						Name    string `json:"name"`
						Address string `json:"address"`
					}{Name: "Bob", Address: "bob@example.com"},
					Type: "required",
				},
			},
			ResponseStatus: struct {
				Response string `json:"response"`
			}{Response: "accepted"},
		},
	}

	result, err := parseCalendarEvents(events, "America/New_York")
	if err != nil {
		t.Fatalf("parseCalendarEvents failed: %v", err)
	}
	if len(result) != 1 {
		t.Fatalf("expected 1 event, got %d", len(result))
	}

	event := result[0]

	// Compute expected Unix timestamps from known UTC times
	loc, _ := time.LoadLocation("America/New_York")
	expectedStart := time.Date(2026, 5, 25, 9, 0, 0, 0, loc).UTC().Unix()
	expectedEnd := time.Date(2026, 5, 25, 10, 0, 0, 0, loc).UTC().Unix()

	if event.StartUnix != expectedStart {
		t.Errorf("StartUnix: got %d, want %d", event.StartUnix, expectedStart)
	}
	if event.EndUnix != expectedEnd {
		t.Errorf("EndUnix: got %d, want %d", event.EndUnix, expectedEnd)
	}

	// Sanity: both should be non-zero
	if event.StartUnix == 0 {
		t.Error("StartUnix is 0, expected non-zero UTC Unix timestamp")
	}
	if event.EndUnix == 0 {
		t.Error("EndUnix is 0, expected non-zero UTC Unix timestamp")
	}

	// StartUnix should be less than EndUnix
	if event.StartUnix >= event.EndUnix {
		t.Errorf("StartUnix (%d) should be less than EndUnix (%d)", event.StartUnix, event.EndUnix)
	}
}

// TestSortAttendeesIsDeterministic verifies the sort is deterministic (same input → same output)
func TestSortAttendeesIsDeterministic(t *testing.T) {
	input := []schema.Attendee{
		{Name: "Z", Email: "z@example.com", Type: "resource"},
		{Name: "A", Email: "a@example.com", Type: "optional"},
		{Name: "M", Email: "m@example.com", Type: "required"},
		{Name: "B", Email: "b@example.com", Type: "required"},
	}

	// Sort multiple times
	results := make([][]schema.Attendee, 5)
	for i := range results {
		attendees := make([]schema.Attendee, len(input))
		copy(attendees, input)
		sortAttendees(attendees)
		results[i] = attendees
	}

	// All results should be identical
	for i := 1; i < len(results); i++ {
		for j := range results[i] {
			if results[i][j] != results[0][j] {
				t.Errorf("sort is non-deterministic: run %d differs from run 0 at index %d", i, j)
			}
		}
	}
}
