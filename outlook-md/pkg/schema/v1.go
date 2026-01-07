package schema

import "time"

// CLIOutput represents the complete JSON output from the CLI (Version 1)
type CLIOutput struct {
	Version  int        `json:"version"`
	Timezone string     `json:"timezone"`
	Window   TimeWindow `json:"window"`
	Events   []CalendarEvent `json:"events"`
}

// TimeWindow represents the query time range
type TimeWindow struct {
	Start time.Time `json:"start"`
	End   time.Time `json:"end"`
}

// CalendarEvent represents a single calendar event from Microsoft Graph
type CalendarEvent struct {
	ID        string     `json:"id"`
	Subject   string     `json:"subject"`
	IsAllDay  bool       `json:"isAllDay"`
	Start     time.Time  `json:"start"`
	End       time.Time  `json:"end"`
	Location  string     `json:"location"`
	Organizer Organizer  `json:"organizer"`
	Attendees []Attendee `json:"attendees"`
}

// Organizer represents the event organizer
type Organizer struct {
	Name  string `json:"name"`
	Email string `json:"email"`
}

// Attendee represents a single event attendee
type Attendee struct {
	Name  string `json:"name"`
	Email string `json:"email"`
	Type  string `json:"type"` // "required", "optional", or "resource"
}

// AttendeeType constants for type validation
const (
	AttendeeTypeRequired AttendeeType = "required"
	AttendeeTypeOptional AttendeeType = "optional"
	AttendeeTypeResource AttendeeType = "resource"
)

// AttendeeType enum for attendee types
type AttendeeType string

// IsValid checks if the attendee type is valid
func (t AttendeeType) IsValid() bool {
	switch t {
	case AttendeeTypeRequired, AttendeeTypeOptional, AttendeeTypeResource:
		return true
	default:
		return false
	}
}
