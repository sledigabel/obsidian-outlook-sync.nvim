package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/obsidian-outlook-sync/outlook-md/internal/calendar"
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
	default:
		return fmt.Errorf("unknown command: %s", command)
	}
}

func printUsage() {
	fmt.Println("Usage: outlook-md <command> [options]")
	fmt.Println("")
	fmt.Println("Commands:")
	fmt.Println("  today    Fetch today's calendar events (00:00-24:00)")
	fmt.Println("")
	fmt.Println("Options:")
	fmt.Println("  --format <format>   Output format (default: json)")
	fmt.Println("  --tz <timezone>     Timezone for calendar view (default: Local)")
	fmt.Println("  --version           Print version and exit")
	fmt.Println("  --help              Show this help message")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  outlook-md today --format json --tz America/New_York")
	fmt.Println("  outlook-md today --tz UTC")
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

	// Get actual timezone name for API (Graph API doesn't accept "Local")
	actualTimezone := timezone
	if timezone == "Local" {
		// Get the system's actual timezone name
		now := time.Now()
		actualTimezone, _ = now.Zone()

		// If we can't get a proper IANA name, try to determine it from the location
		if actualTimezone == "" || len(actualTimezone) <= 3 {
			// Common fallback: try to get it from the location
			// For "Local", this will try to determine the IANA name
			if loc.String() != "Local" {
				actualTimezone = loc.String()
			} else {
				// Last resort: use UTC
				actualTimezone = "UTC"
			}
		}
	}

	// Calculate today's window (00:00 to 24:00 in specified timezone)
	now := time.Now().In(loc)
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
	endOfDay := startOfDay.Add(24 * time.Hour)

	// TODO: Load configuration (Phase 5)
	// For now, we'll skip config loading since we're using env var directly
	// cfg, err := config.Load()
	// if err != nil {
	// 	return fmt.Errorf("failed to load configuration: %w", err)
	// }

	// TODO: Implement authentication (Phase 5)
	// For now, assume we have a valid access token
	accessToken := os.Getenv("OUTLOOK_MD_ACCESS_TOKEN")
	if accessToken == "" {
		return fmt.Errorf("no access token available. Set OUTLOOK_MD_ACCESS_TOKEN environment variable or complete device-code flow authentication (not yet implemented)")
	}

	// Create Graph API client
	client := calendar.NewGraphClient(accessToken)

	// Fetch calendar events (use actual timezone name, not "Local")
	ctx := context.Background()
	events, err := client.GetCalendarView(ctx, startOfDay, endOfDay, actualTimezone)
	if err != nil {
		return fmt.Errorf("failed to fetch calendar events: %w", err)
	}

	// Build output
	cliOutput := &schema.CLIOutput{
		Version:  1,
		Timezone: actualTimezone,  // Use actual timezone in output
		Window: schema.TimeWindow{
			Start: startOfDay,
			End:   endOfDay,
		},
		Events: events,
	}

	// Format and write output
	if err := output.FormatJSON(cliOutput, os.Stdout); err != nil {
		return fmt.Errorf("failed to format output: %w", err)
	}

	return nil
}
