package output_test

import (
	"bytes"
	"encoding/json"
	"testing"
	"time"

	"github.com/obsidian-outlook-sync/outlook-md/internal/output"
	"github.com/obsidian-outlook-sync/outlook-md/pkg/schema"
)

func TestFormatJSON(t *testing.T) {
	// Create sample events
	now := time.Date(2026, 1, 7, 9, 0, 0, 0, time.UTC)
	events := []schema.CalendarEvent{
		{
			ID:       "test-event-1",
			Subject:  "Test Meeting",
			IsAllDay: false,
			Start:    now,
			End:      now.Add(30 * time.Minute),
			Location: "Room 101",
			Organizer: schema.Organizer{
				Name:  "Alice Smith",
				Email: "alice@example.com",
			},
			Attendees: []schema.Attendee{
				{Name: "Bob", Email: "bob@example.com", Type: "required"},
			},
		},
	}

	cliOutput := &schema.CLIOutput{
		Version:  1,
		Timezone: "UTC",
		Window: schema.TimeWindow{
			Start: now,
			End:   now.Add(24 * time.Hour),
		},
		Events: events,
	}

	// Format to JSON
	var buf bytes.Buffer
	if err := output.FormatJSON(cliOutput, &buf); err != nil {
		t.Fatalf("FormatJSON failed: %v", err)
	}

	// Parse back to verify structure
	var parsed schema.CLIOutput
	if err := json.Unmarshal(buf.Bytes(), &parsed); err != nil {
		t.Fatalf("Failed to parse JSON output: %v", err)
	}

	// Verify fields
	if parsed.Version != 1 {
		t.Errorf("Expected version 1, got %d", parsed.Version)
	}
	if parsed.Timezone != "UTC" {
		t.Errorf("Expected timezone UTC, got %s", parsed.Timezone)
	}
	if len(parsed.Events) != 1 {
		t.Errorf("Expected 1 event, got %d", len(parsed.Events))
	}
}

func TestFormatJSON_EmptyEvents(t *testing.T) {
	now := time.Now()
	cliOutput := &schema.CLIOutput{
		Version:  1,
		Timezone: "America/New_York",
		Window: schema.TimeWindow{
			Start: now,
			End:   now.Add(24 * time.Hour),
		},
		Events: []schema.CalendarEvent{}, // Empty array, not nil
	}

	var buf bytes.Buffer
	if err := output.FormatJSON(cliOutput, &buf); err != nil {
		t.Fatalf("FormatJSON failed with empty events: %v", err)
	}

	// Verify empty events array is preserved
	var parsed schema.CLIOutput
	json.Unmarshal(buf.Bytes(), &parsed)
	if parsed.Events == nil {
		t.Error("Events should be empty array, not nil")
	}
	if len(parsed.Events) != 0 {
		t.Errorf("Expected 0 events, got %d", len(parsed.Events))
	}
}
