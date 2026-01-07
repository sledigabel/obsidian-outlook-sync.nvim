package calendar

import (
	"testing"

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
