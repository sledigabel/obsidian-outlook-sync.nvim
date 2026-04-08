package main

import (
	"testing"
	"time"
)

func TestGetActualTimezone_ExplicitIANA(t *testing.T) {
	// When user provides an explicit IANA name, it should be returned as-is.
	loc, _ := time.LoadLocation("America/New_York")
	result := getActualTimezone("America/New_York", loc)
	if result != "America/New_York" {
		t.Errorf("expected America/New_York, got %s", result)
	}
}

func TestGetActualTimezone_UTC(t *testing.T) {
	loc, _ := time.LoadLocation("UTC")
	result := getActualTimezone("UTC", loc)
	if result != "UTC" {
		t.Errorf("expected UTC, got %s", result)
	}
}

func TestGetActualTimezone_Local(t *testing.T) {
	// When timezone is "Local", should resolve to a valid IANA name, never
	// a short abbreviation like "BST" or "GMT".
	loc, _ := time.LoadLocation("Local")
	result := getActualTimezone("Local", loc)

	if result == "" {
		t.Fatal("expected non-empty timezone, got empty string")
	}

	// Must not be a short abbreviation (BST, GMT, CET, etc.)
	// Valid IANA names contain '/' (e.g. "Europe/London", "America/New_York")
	// with the sole exception of "UTC".
	if result != "UTC" && !ianaPattern.MatchString(result) {
		t.Errorf("expected IANA timezone name (Region/City or UTC), got %q", result)
	}

	t.Logf("resolved local timezone to: %s", result)
}

func TestResolveSystemIANA(t *testing.T) {
	iana := resolveSystemIANA()
	// On macOS/Linux CI this should return something valid
	if iana == "" {
		t.Skip("could not resolve system IANA timezone (may be expected on some platforms)")
	}
	if !ianaPattern.MatchString(iana) {
		t.Errorf("expected IANA timezone (Region/City), got %q", iana)
	}
	t.Logf("system IANA timezone: %s", iana)
}
