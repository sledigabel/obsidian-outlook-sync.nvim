package tests

import (
	"encoding/json"
	"testing"

	"github.com/obsidian-outlook-sync/outlook-md/pkg/schema"
)

// ValidateCLIOutput validates that a CLIOutput conforms to the JSON schema v1
func ValidateCLIOutput(t *testing.T, output *schema.CLIOutput) {
	t.Helper()

	// Version must be 1
	if output.Version != 1 {
		t.Errorf("Expected version 1, got %d", output.Version)
	}

	// Timezone must be non-empty
	if output.Timezone == "" {
		t.Error("Timezone must not be empty")
	}

	// Window must have valid start/end
	if output.Window.Start.IsZero() {
		t.Error("Window start time must not be zero")
	}
	if output.Window.End.IsZero() {
		t.Error("Window end time must not be zero")
	}
	if !output.Window.Start.Before(output.Window.End) {
		t.Error("Window start must be before end")
	}

	// Events array must be present (can be empty)
	if output.Events == nil {
		t.Error("Events must not be nil (use empty array [])")
	}

	// Validate each event
	for i, event := range output.Events {
		ValidateCalendarEvent(t, &event, i)
	}
}

// ValidateCalendarEvent validates a single calendar event
func ValidateCalendarEvent(t *testing.T, event *schema.CalendarEvent, index int) {
	t.Helper()

	// ID must be non-empty
	if event.ID == "" {
		t.Errorf("Event %d: ID must not be empty", index)
	}

	// Subject can be empty (will render as "(Untitled Event)")
	// No validation needed

	// Start/end times must be valid
	if event.Start.IsZero() {
		t.Errorf("Event %d: Start time must not be zero", index)
	}
	if event.End.IsZero() {
		t.Errorf("Event %d: End time must not be zero", index)
	}
	if !event.IsAllDay && !event.Start.Before(event.End) {
		t.Errorf("Event %d: Start must be before end", index)
	}

	// Location can be empty
	// No validation needed

	// Organizer must have name and email (can be empty strings)
	// No validation needed (Graph API guarantees presence)

	// Attendees must be present (can be empty array)
	if event.Attendees == nil {
		t.Errorf("Event %d: Attendees must not be nil (use empty array [])", index)
	}

	// Validate attendee types
	for j, attendee := range event.Attendees {
		if attendee.Type != "required" && attendee.Type != "optional" && attendee.Type != "resource" {
			t.Errorf("Event %d, Attendee %d: Invalid type '%s' (must be required/optional/resource)", index, j, attendee.Type)
		}
	}
}

// ValidateJSONParsing ensures output can be marshaled and unmarshaled
func ValidateJSONParsing(t *testing.T, output *schema.CLIOutput) {
	t.Helper()

	// Marshal to JSON
	jsonBytes, err := json.Marshal(output)
	if err != nil {
		t.Fatalf("Failed to marshal CLIOutput to JSON: %v", err)
	}

	// Unmarshal back
	var parsed schema.CLIOutput
	if err := json.Unmarshal(jsonBytes, &parsed); err != nil {
		t.Fatalf("Failed to unmarshal JSON to CLIOutput: %v", err)
	}

	// Basic sanity checks
	if parsed.Version != output.Version {
		t.Error("Version mismatch after JSON round-trip")
	}
	if len(parsed.Events) != len(output.Events) {
		t.Error("Events count mismatch after JSON round-trip")
	}
}

// TestSchemaValidation is a placeholder test to ensure the package compiles
func TestSchemaValidation(t *testing.T) {
	// This test will be expanded in Phase 3 (User Story 1)
	t.Skip("Placeholder test - will be implemented in Phase 3")
}
