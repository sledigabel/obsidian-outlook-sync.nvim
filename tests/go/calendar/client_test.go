package calendar

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/obsidian-outlook-sync/outlook-md/internal/calendar"
)

// TestGetCalendarView_EmptyResponse tests fetching calendar when no events exist
func TestGetCalendarView_EmptyResponse(t *testing.T) {
	// Load test fixture
	mockResponse := loadTestData(t, "calendar_response_empty.json")

	// Create mock server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify request headers
		if r.Header.Get("Authorization") != "Bearer test-token" {
			t.Errorf("Expected Authorization header with bearer token")
		}

		// Verify query parameters
		query := r.URL.Query()
		if query.Get("startDateTime") == "" || query.Get("endDateTime") == "" {
			t.Errorf("Expected startDateTime and endDateTime query parameters")
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(mockResponse)
	}))
	defer server.Close()

	// Create client with mock server URL
	client := calendar.NewGraphClientWithBaseURL("test-token", server.URL)

	// Execute request
	ctx := context.Background()
	start := time.Date(2026, 1, 7, 0, 0, 0, 0, time.UTC)
	end := start.Add(24 * time.Hour)

	events, err := client.GetCalendarView(ctx, start, end, "UTC")

	// Verify results
	if err != nil {
		t.Fatalf("GetCalendarView failed: %v", err)
	}
	if events == nil {
		t.Fatal("Events should not be nil (use empty array)")
	}
	if len(events) != 0 {
		t.Errorf("Expected 0 events, got %d", len(events))
	}
}

// TestGetCalendarView_SingleEvent tests fetching a single event
func TestGetCalendarView_SingleEvent(t *testing.T) {
	mockResponse := loadTestData(t, "calendar_response_single.json")

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(mockResponse)
	}))
	defer server.Close()

	client := calendar.NewGraphClientWithBaseURL("test-token", server.URL)

	ctx := context.Background()
	start := time.Date(2026, 1, 7, 0, 0, 0, 0, time.UTC)
	end := start.Add(24 * time.Hour)

	events, err := client.GetCalendarView(ctx, start, end, "America/New_York")

	// Verify results
	if err != nil {
		t.Fatalf("GetCalendarView failed: %v", err)
	}
	if len(events) != 1 {
		t.Fatalf("Expected 1 event, got %d", len(events))
	}

	// Verify event fields
	event := events[0]
	if event.ID != "AAMkAGI2THVSAAA=" {
		t.Errorf("Expected ID 'AAMkAGI2THVSAAA=', got '%s'", event.ID)
	}
	if event.Subject != "Team Standup" {
		t.Errorf("Expected subject 'Team Standup', got '%s'", event.Subject)
	}
	if event.IsAllDay {
		t.Error("Expected isAllDay to be false")
	}
	if event.Location != "Conference Room A" {
		t.Errorf("Expected location 'Conference Room A', got '%s'", event.Location)
	}

	// Verify organizer
	if event.Organizer.Name != "Alice Smith" {
		t.Errorf("Expected organizer name 'Alice Smith', got '%s'", event.Organizer.Name)
	}
	if event.Organizer.Email != "alice@example.com" {
		t.Errorf("Expected organizer email 'alice@example.com', got '%s'", event.Organizer.Email)
	}

	// Verify attendees (2 attendees in fixture)
	if len(event.Attendees) != 2 {
		t.Fatalf("Expected 2 attendees, got %d", len(event.Attendees))
	}
	if event.Attendees[0].Name != "Bob Jones" {
		t.Errorf("Expected attendee name 'Bob Jones', got '%s'", event.Attendees[0].Name)
	}
	if event.Attendees[0].Type != "required" {
		t.Errorf("Expected attendee type 'required', got '%s'", event.Attendees[0].Type)
	}
	if event.Attendees[1].Name != "Carol White" {
		t.Errorf("Expected attendee name 'Carol White', got '%s'", event.Attendees[1].Name)
	}
	if event.Attendees[1].Type != "optional" {
		t.Errorf("Expected attendee type 'optional', got '%s'", event.Attendees[1].Type)
	}
}

// TestGetCalendarView_ManyEvents tests fetching multiple events
func TestGetCalendarView_ManyEvents(t *testing.T) {
	mockResponse := loadTestData(t, "calendar_response_many.json")

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(mockResponse)
	}))
	defer server.Close()

	client := calendar.NewGraphClientWithBaseURL("test-token", server.URL)

	ctx := context.Background()
	start := time.Date(2026, 1, 7, 0, 0, 0, 0, time.UTC)
	end := start.Add(24 * time.Hour)

	events, err := client.GetCalendarView(ctx, start, end, "UTC")

	// Verify results
	if err != nil {
		t.Fatalf("GetCalendarView failed: %v", err)
	}
	// Expecting 1 event because the first event has no attendees and user is organizer (filtered out)
	if len(events) != 1 {
		t.Errorf("Expected 1 event, got %d", len(events))
	}

	// Verify events are in chronological order
	for i := 1; i < len(events); i++ {
		if events[i].Start.Before(events[i-1].Start) {
			t.Errorf("Events not in chronological order at index %d", i)
		}
	}
}

// TestGetCalendarView_AllDayEvent tests fetching all-day events
func TestGetCalendarView_AllDayEvent(t *testing.T) {
	mockResponse := loadTestData(t, "calendar_response_allday.json")

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(mockResponse)
	}))
	defer server.Close()

	client := calendar.NewGraphClientWithBaseURL("test-token", server.URL)

	ctx := context.Background()
	start := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	end := start.Add(24 * time.Hour)

	events, err := client.GetCalendarView(ctx, start, end, "America/New_York")

	// Verify results
	if err != nil {
		t.Fatalf("GetCalendarView failed: %v", err)
	}
	if len(events) != 1 {
		t.Fatalf("Expected 1 event, got %d", len(events))
	}

	event := events[0]
	if !event.IsAllDay {
		t.Error("Expected isAllDay to be true")
	}
	if event.Subject != "Company Holiday - New Year" {
		t.Errorf("Expected subject 'Company Holiday - New Year', got '%s'", event.Subject)
	}
	if len(event.Attendees) != 0 {
		t.Errorf("Expected 0 attendees for all-day event, got %d", len(event.Attendees))
	}
}

// TestGetCalendarView_FilterOrganizerNoAttendees tests that events where the user
// is the organizer with no attendees are filtered out
func TestGetCalendarView_FilterOrganizerNoAttendees(t *testing.T) {
	// Create a response with one event where user is organizer with no attendees
	mockResponse := []byte(`{
		"value": [
			{
				"id": "SOLO-EVENT-001",
				"subject": "Personal Task",
				"isAllDay": false,
				"start": {
					"dateTime": "2026-01-07T10:00:00",
					"timeZone": "UTC"
				},
				"end": {
					"dateTime": "2026-01-07T11:00:00",
					"timeZone": "UTC"
				},
				"location": {
					"displayName": ""
				},
				"organizer": {
					"emailAddress": {
						"name": "Me",
						"address": "me@example.com"
					}
				},
				"attendees": [],
				"responseStatus": {
					"response": "organizer"
				}
			}
		]
	}`)

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(mockResponse)
	}))
	defer server.Close()

	client := calendar.NewGraphClientWithBaseURL("test-token", server.URL)

	ctx := context.Background()
	start := time.Date(2026, 1, 7, 0, 0, 0, 0, time.UTC)
	end := start.Add(24 * time.Hour)

	events, err := client.GetCalendarView(ctx, start, end, "UTC")

	// Verify results - should filter out the solo organizer event
	if err != nil {
		t.Fatalf("GetCalendarView failed: %v", err)
	}
	if len(events) != 0 {
		t.Errorf("Expected 0 events (solo organizer events should be filtered), got %d", len(events))
	}
}

// TestGetCalendarView_HTTPError tests handling of HTTP errors
func TestGetCalendarView_HTTPError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"error": {"code": "InvalidAuthenticationToken", "message": "Access token is invalid"}}`))
	}))
	defer server.Close()

	client := calendar.NewGraphClientWithBaseURL("invalid-token", server.URL)

	ctx := context.Background()
	start := time.Now()
	end := start.Add(24 * time.Hour)

	events, err := client.GetCalendarView(ctx, start, end, "UTC")

	// Should return error
	if err == nil {
		t.Fatal("Expected error for HTTP 401, got nil")
	}
	if events != nil {
		t.Error("Expected nil events on error")
	}
}

// TestGetCalendarView_MalformedJSON tests handling of malformed JSON responses
func TestGetCalendarView_MalformedJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"value": [invalid json}`))
	}))
	defer server.Close()

	client := calendar.NewGraphClientWithBaseURL("test-token", server.URL)

	ctx := context.Background()
	start := time.Now()
	end := start.Add(24 * time.Hour)

	events, err := client.GetCalendarView(ctx, start, end, "UTC")

	// Should return error
	if err == nil {
		t.Fatal("Expected error for malformed JSON, got nil")
	}
	if events != nil {
		t.Error("Expected nil events on error")
	}
}

// TestGetCalendarView_Timeout tests handling of context timeout
func TestGetCalendarView_Timeout(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Simulate slow response
		time.Sleep(2 * time.Second)
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	client := calendar.NewGraphClientWithBaseURL("test-token", server.URL)

	// Create context with short timeout
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	start := time.Now()
	end := start.Add(24 * time.Hour)

	events, err := client.GetCalendarView(ctx, start, end, "UTC")

	// Should return timeout error
	if err == nil {
		t.Fatal("Expected timeout error, got nil")
	}
	if events != nil {
		t.Error("Expected nil events on timeout")
	}
}

// loadTestData loads test fixture from testdata directory
func loadTestData(t *testing.T, filename string) []byte {
	t.Helper()

	// Path is relative to test file location
	path := filepath.Join("..", "testdata", filename)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("Failed to load test data %s: %v", filename, err)
	}
	return data
}

// Verify test fixtures are valid JSON and can be unmarshaled
func TestValidateTestFixtures(t *testing.T) {
	fixtures := []string{
		"calendar_response_empty.json",
		"calendar_response_single.json",
		"calendar_response_many.json",
		"calendar_response_allday.json",
	}

	for _, fixture := range fixtures {
		t.Run(fixture, func(t *testing.T) {
			data := loadTestData(t, fixture)

			// Verify it's valid JSON
			if !json.Valid(data) {
				t.Errorf("Invalid JSON in fixture %s", fixture)
			}

			// Parse as generic map to ensure structure is valid
			var response map[string]interface{}
			if err := json.Unmarshal(data, &response); err != nil {
				t.Errorf("Failed to parse %s: %v", fixture, err)
			}

			// Verify it has a "value" key (Graph API format)
			if _, ok := response["value"]; !ok {
				t.Errorf("Fixture %s missing 'value' key", fixture)
			}
		})
	}
}
