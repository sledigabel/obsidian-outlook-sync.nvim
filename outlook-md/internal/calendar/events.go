package calendar

import (
	"sort"
	"strings"

	"github.com/obsidian-outlook-sync/outlook-md/pkg/schema"
)

// sortAttendees sorts attendees deterministically using a multi-key comparison
// Per FR-026: Primary by type (required < optional < resource),
// secondary by email (case-insensitive), tertiary by name (case-insensitive)
func sortAttendees(attendees []schema.Attendee) {
	sort.SliceStable(attendees, func(i, j int) bool {
		a, b := attendees[i], attendees[j]

		// Primary: type (required < optional < resource)
		typeOrder := map[string]int{"required": 0, "optional": 1, "resource": 2}
		typeA := typeOrder[a.Type]
		typeB := typeOrder[b.Type]
		if typeA != typeB {
			return typeA < typeB
		}

		// Secondary: email (case-insensitive)
		emailA := strings.ToLower(a.Email)
		emailB := strings.ToLower(b.Email)
		if emailA != emailB {
			return emailA < emailB
		}

		// Tertiary: name (case-insensitive)
		nameA := strings.ToLower(a.Name)
		nameB := strings.ToLower(b.Name)
		return nameA < nameB
	})
}
