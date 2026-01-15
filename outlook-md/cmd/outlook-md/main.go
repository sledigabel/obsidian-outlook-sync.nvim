package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/obsidian-outlook-sync/outlook-md/internal/auth"
	"github.com/obsidian-outlook-sync/outlook-md/internal/calendar"
	"github.com/obsidian-outlook-sync/outlook-md/internal/config"
	"github.com/obsidian-outlook-sync/outlook-md/internal/output"
	"github.com/obsidian-outlook-sync/outlook-md/pkg/schema"
)

const (
	version = "0.1.0"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	// Define global flags
	var (
		formatFlag   = flag.String("format", "json", "Output format (json only for now)")
		timezoneFlag = flag.String("tz", "Local", "Timezone for calendar view (e.g., America/New_York, UTC)")
		versionFlag  = flag.Bool("version", false, "Print version and exit")
		helpFlag     = flag.Bool("help", false, "Show help")
	)

	flag.Parse()

	// Handle version flag
	if *versionFlag {
		fmt.Printf("outlook-md version %s\n", version)
		return nil
	}

	// Handle help flag
	if *helpFlag || flag.NArg() == 0 {
		printUsage()
		return nil
	}

	// Get command
	command := flag.Arg(0)

	// Route to command handler
	switch command {
	case "today":
		return handleTodayCommand(*formatFlag, *timezoneFlag)
	case "tomorrow":
		return handleTomorrowCommand(*formatFlag, *timezoneFlag)
	case "week":
		return handleWeekCommand(*formatFlag, *timezoneFlag)
	default:
		return fmt.Errorf("unknown command: %s", command)
	}
}

func printUsage() {
	fmt.Println("Usage: outlook-md <command> [options]")
	fmt.Println("")
	fmt.Println("Commands:")
	fmt.Println("  today      Fetch today's calendar events (00:00-24:00)")
	fmt.Println("  tomorrow   Fetch tomorrow's calendar events (00:00-24:00)")
	fmt.Println("  week       Fetch this week's calendar events (Mon-Sun)")
	fmt.Println("")
	fmt.Println("Options:")
	fmt.Println("  --format <format>   Output format (default: json)")
	fmt.Println("  --tz <timezone>     Timezone for calendar view (default: Local)")
	fmt.Println("  --version           Print version and exit")
	fmt.Println("  --help              Show this help message")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  outlook-md today --format json --tz America/New_York")
	fmt.Println("  outlook-md tomorrow --tz UTC")
	fmt.Println("  outlook-md week --tz Europe/London")
}

func handleTodayCommand(format string, timezone string) error {
	// Validate format
	if format != "json" {
		return fmt.Errorf("unsupported format: %s (only 'json' is supported)", format)
	}

	// Load timezone
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return fmt.Errorf("invalid timezone: %w", err)
	}

	// Get actual timezone name for API
	actualTimezone := getActualTimezone(timezone, loc)

	// Calculate today's window (00:00 to 24:00 in specified timezone)
	now := time.Now().In(loc)
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
	endOfDay := startOfDay.Add(24 * time.Hour)

	return fetchAndOutputEvents(format, actualTimezone, startOfDay, endOfDay)
}

// getAccessToken retrieves an OAuth2 access token
// Priority: 1) Environment variable, 2) Cached token, 3) Device-code flow
func getAccessToken() (string, error) {
	// First, check for env var (for testing and manual override)
	envToken := os.Getenv("OUTLOOK_MD_ACCESS_TOKEN")
	if envToken != "" {
		return envToken, nil
	}

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		return "", fmt.Errorf("failed to load configuration: %w", err)
	}

	// Determine cache file location
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("failed to get home directory: %w", err)
	}
	cacheDir := filepath.Join(homeDir, ".outlook-md")
	cacheFile := filepath.Join(cacheDir, "token.json")

	// Create cache directory if it doesn't exist
	if err := os.MkdirAll(cacheDir, 0700); err != nil {
		return "", fmt.Errorf("failed to create cache directory: %w", err)
	}

	// Create token cache
	tokenCache := auth.NewTokenCache(cacheFile)

	// Try to load cached token
	token, err := tokenCache.Load()
	if err == nil {
		// Token loaded successfully, check if it needs refresh
		tokenSource := auth.NewTokenSource(token, cfg.ClientID, cfg.TenantID, tokenCache)
		refreshedToken, err := tokenSource.Token()
		if err != nil {
			// Token refresh failed, need to re-authenticate
			fmt.Fprintf(os.Stderr, "Warning: Failed to refresh token: %v\n", err)
			fmt.Fprintf(os.Stderr, "Re-authenticating...\n\n")
		} else {
			// Token is valid or was refreshed successfully
			return refreshedToken.AccessToken, nil
		}
	} else if !os.IsNotExist(err) {
		// Unexpected error loading cache (not just "file not found")
		return "", fmt.Errorf("failed to load token cache: %w", err)
	}

	// No cached token or refresh failed - initiate device code flow
	authenticator := auth.NewDeviceCodeAuthenticator(cfg.ClientID, cfg.TenantID)
	ctx := context.Background()
	token, err = authenticator.Authenticate(ctx)
	if err != nil {
		return "", fmt.Errorf("device code authentication failed: %w", err)
	}

	// Save token to cache
	if err := tokenCache.Save(token); err != nil {
		// Log warning but don't fail - we have a valid token
		fmt.Fprintf(os.Stderr, "Warning: Failed to save token to cache: %v\n", err)
	}

	return token.AccessToken, nil
}

// handleTomorrowCommand fetches tomorrow's calendar events
func handleTomorrowCommand(format string, timezone string) error {
	// Validate format
	if format != "json" {
		return fmt.Errorf("unsupported format: %s (only 'json' is supported)", format)
	}

	// Load timezone
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return fmt.Errorf("invalid timezone: %w", err)
	}

	// Get actual timezone name for API
	actualTimezone := getActualTimezone(timezone, loc)

	// Calculate tomorrow's window (00:00 to 24:00 in specified timezone)
	now := time.Now().In(loc)
	tomorrow := now.Add(24 * time.Hour)
	startOfTomorrow := time.Date(tomorrow.Year(), tomorrow.Month(), tomorrow.Day(), 0, 0, 0, 0, loc)
	endOfTomorrow := startOfTomorrow.Add(24 * time.Hour)

	return fetchAndOutputEvents(format, actualTimezone, startOfTomorrow, endOfTomorrow)
}

// handleWeekCommand fetches this week's calendar events (Monday-Sunday)
func handleWeekCommand(format string, timezone string) error {
	// Validate format
	if format != "json" {
		return fmt.Errorf("unsupported format: %s (only 'json' is supported)", format)
	}

	// Load timezone
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return fmt.Errorf("invalid timezone: %w", err)
	}

	// Get actual timezone name for API
	actualTimezone := getActualTimezone(timezone, loc)

	// Calculate this week's window (Monday 00:00 to Sunday 24:00 in specified timezone)
	now := time.Now().In(loc)

	// Find this Monday
	weekday := now.Weekday()
	daysUntilMonday := int(time.Monday - weekday)
	if daysUntilMonday > 0 {
		daysUntilMonday -= 7 // Go back to last Monday
	}
	monday := now.AddDate(0, 0, daysUntilMonday)
	startOfWeek := time.Date(monday.Year(), monday.Month(), monday.Day(), 0, 0, 0, 0, loc)

	// Find next Monday (which is end of this week)
	endOfWeek := startOfWeek.AddDate(0, 0, 7)

	return fetchAndOutputEvents(format, actualTimezone, startOfWeek, endOfWeek)
}

// getActualTimezone converts "Local" to actual IANA timezone name
func getActualTimezone(timezone string, loc *time.Location) string {
	actualTimezone := timezone
	if timezone == "Local" {
		now := time.Now()
		actualTimezone, _ = now.Zone()

		if actualTimezone == "" || len(actualTimezone) <= 3 {
			if loc.String() != "Local" {
				actualTimezone = loc.String()
			} else {
				actualTimezone = "UTC"
			}
		}
	}
	return actualTimezone
}

// fetchAndOutputEvents is a helper to fetch and format calendar events
func fetchAndOutputEvents(format string, timezone string, start, end time.Time) error {
	// Get access token
	accessToken, err := getAccessToken()
	if err != nil {
		return fmt.Errorf("authentication failed: %w", err)
	}

	// Create Graph API client
	client := calendar.NewGraphClient(accessToken)

	// Fetch calendar events
	ctx := context.Background()
	events, err := client.GetCalendarView(ctx, start, end, timezone)
	if err != nil {
		return fmt.Errorf("failed to fetch calendar events: %w", err)
	}

	// Build output
	cliOutput := &schema.CLIOutput{
		Version:  1,
		Timezone: timezone,
		Window: schema.TimeWindow{
			Start: start,
			End:   end,
		},
		Events: events,
	}

	// Format and write output
	if err := output.FormatJSON(cliOutput, os.Stdout); err != nil {
		return fmt.Errorf("failed to format output: %w", err)
	}

	return nil
}
