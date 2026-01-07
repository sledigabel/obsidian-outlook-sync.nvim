package calendar

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"time"

	"github.com/obsidian-outlook-sync/outlook-md/pkg/schema"
)

// GraphClient defines the interface for Microsoft Graph calendar operations
// This interface enables mocking for testing (per research.md AD-001)
type GraphClient interface {
	// GetCalendarView fetches calendar events within the specified time window
	GetCalendarView(ctx context.Context, start, end time.Time, timezone string) ([]schema.CalendarEvent, error)
}

// Ensure interface is implemented at compile time
var _ GraphClient = (*graphClientImpl)(nil)

// graphClientImpl implements the GraphClient interface
type graphClientImpl struct {
	accessToken string
	baseURL     string
	httpClient  *http.Client
}

// NewGraphClient creates a new Microsoft Graph client
func NewGraphClient(accessToken string) GraphClient {
	return &graphClientImpl{
		accessToken: accessToken,
		baseURL:     "https://graph.microsoft.com/v1.0",
		httpClient:  &http.Client{Timeout: 30 * time.Second},
	}
}

// NewGraphClientWithBaseURL creates a new Microsoft Graph client with a custom base URL
// This is primarily used for testing with mock servers
func NewGraphClientWithBaseURL(accessToken, baseURL string) GraphClient {
	return &graphClientImpl{
		accessToken: accessToken,
		baseURL:     baseURL,
		httpClient:  &http.Client{Timeout: 30 * time.Second},
	}
}

// GetCalendarView implements the GraphClient interface
func (c *graphClientImpl) GetCalendarView(ctx context.Context, start, end time.Time, timezone string) ([]schema.CalendarEvent, error) {
	// Build URL with query parameters
	endpoint := fmt.Sprintf("%s/me/calendarView", c.baseURL)
	u, err := url.Parse(endpoint)
	if err != nil {
		return nil, fmt.Errorf("failed to parse endpoint URL: %w", err)
	}

	// Add query parameters
	q := u.Query()
	q.Set("startDateTime", start.Format(time.RFC3339))
	q.Set("endDateTime", end.Format(time.RFC3339))
	u.RawQuery = q.Encode()

	// Create HTTP request
	req, err := http.NewRequestWithContext(ctx, "GET", u.String(), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Set headers
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", c.accessToken))
	req.Header.Set("Prefer", fmt.Sprintf("outlook.timezone=\"%s\"", timezone))
	req.Header.Set("Content-Type", "application/json")

	// Execute request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	// Check status code
	if resp.StatusCode != http.StatusOK {
		// Read error response body
		bodyBytes, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("Graph API returned status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	// Parse response
	var graphResp graphCalendarResponse
	if err := json.NewDecoder(resp.Body).Decode(&graphResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Convert Graph API events to schema.CalendarEvent
	events, err := parseCalendarEvents(graphResp.Value, timezone)
	if err != nil {
		return nil, fmt.Errorf("failed to parse events: %w", err)
	}

	return events, nil
}

// graphCalendarResponse represents the Microsoft Graph API response
type graphCalendarResponse struct {
	Value []graphEvent `json:"value"`
}

// graphEvent represents a calendar event from Microsoft Graph API
type graphEvent struct {
	ID       string `json:"id"`
	Subject  string `json:"subject"`
	IsAllDay bool   `json:"isAllDay"`
	Start    struct {
		DateTime string `json:"dateTime"`
		TimeZone string `json:"timeZone"`
	} `json:"start"`
	End struct {
		DateTime string `json:"dateTime"`
		TimeZone string `json:"timeZone"`
	} `json:"end"`
	Location struct {
		DisplayName string `json:"displayName"`
	} `json:"location"`
	Organizer struct {
		EmailAddress struct {
			Name    string `json:"name"`
			Address string `json:"address"`
		} `json:"emailAddress"`
	} `json:"organizer"`
	Attendees []struct {
		EmailAddress struct {
			Name    string `json:"name"`
			Address string `json:"address"`
		} `json:"emailAddress"`
		Type string `json:"type"` // "required", "optional", or "resource"
	} `json:"attendees"`
}

// parseCalendarEvents converts Graph API events to our schema
func parseCalendarEvents(graphEvents []graphEvent, timezone string) ([]schema.CalendarEvent, error) {
	events := make([]schema.CalendarEvent, 0, len(graphEvents))

	// Load timezone for parsing
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return nil, fmt.Errorf("invalid timezone: %w", err)
	}

	for _, ge := range graphEvents {
		// Parse start/end times
		start, err := parseDateTime(ge.Start.DateTime, loc)
		if err != nil {
			return nil, fmt.Errorf("failed to parse start time for event %s: %w", ge.ID, err)
		}

		end, err := parseDateTime(ge.End.DateTime, loc)
		if err != nil {
			return nil, fmt.Errorf("failed to parse end time for event %s: %w", ge.ID, err)
		}

		// Convert attendees
		attendees := make([]schema.Attendee, len(ge.Attendees))
		for i, a := range ge.Attendees {
			attendees[i] = schema.Attendee{
				Name:  a.EmailAddress.Name,
				Email: a.EmailAddress.Address,
				Type:  a.Type,
			}
		}

		// Sort attendees deterministically per FR-026
		sortAttendees(attendees)

		// Build event
		event := schema.CalendarEvent{
			ID:       ge.ID,
			Subject:  ge.Subject,
			IsAllDay: ge.IsAllDay,
			Start:    start,
			End:      end,
			Location: ge.Location.DisplayName,
			Organizer: schema.Organizer{
				Name:  ge.Organizer.EmailAddress.Name,
				Email: ge.Organizer.EmailAddress.Address,
			},
			Attendees: attendees,
		}

		events = append(events, event)
	}

	// Sort events chronologically
	sort.Slice(events, func(i, j int) bool {
		return events[i].Start.Before(events[j].Start)
	})

	return events, nil
}

// parseDateTime parses a datetime string in the given timezone
func parseDateTime(dtStr string, loc *time.Location) (time.Time, error) {
	// Try parsing as RFC3339 first
	t, err := time.Parse(time.RFC3339, dtStr)
	if err == nil {
		return t.In(loc), nil
	}

	// Try parsing without timezone info (Graph API sometimes returns this format)
	t, err = time.ParseInLocation("2006-01-02T15:04:05", dtStr, loc)
	if err != nil {
		return time.Time{}, fmt.Errorf("failed to parse datetime '%s': %w", dtStr, err)
	}

	return t, nil
}
