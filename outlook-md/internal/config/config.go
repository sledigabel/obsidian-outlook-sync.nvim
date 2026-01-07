package config

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
)

// Config holds application configuration
type Config struct {
	ClientID string
	TenantID string
}

// Load loads configuration from Keychain (macOS) or environment variables
func Load() (*Config, error) {
	cfg := &Config{}

	// Try to load from Keychain first (macOS only)
	if runtime.GOOS == "darwin" {
		clientID, err := getFromKeychain("client-id")
		if err == nil && clientID != "" {
			cfg.ClientID = clientID
		}

		tenantID, err := getFromKeychain("tenant-id")
		if err == nil && tenantID != "" {
			cfg.TenantID = tenantID
		}
	}

	// Fallback to environment variables if not found in Keychain
	if cfg.ClientID == "" {
		cfg.ClientID = os.Getenv("OUTLOOK_MD_CLIENT_ID")
	}
	if cfg.TenantID == "" {
		cfg.TenantID = os.Getenv("OUTLOOK_MD_TENANT_ID")
	}

	// Validate that both are set
	if cfg.ClientID == "" {
		return nil, fmt.Errorf("client ID not found. Please set OUTLOOK_MD_CLIENT_ID environment variable or add to Keychain:\n  security add-generic-password -s com.github.obsidian-outlook-sync -a client-id -w '<YOUR_CLIENT_ID>'")
	}
	if cfg.TenantID == "" {
		return nil, fmt.Errorf("tenant ID not found. Please set OUTLOOK_MD_TENANT_ID environment variable or add to Keychain:\n  security add-generic-password -s com.github.obsidian-outlook-sync -a tenant-id -w '<YOUR_TENANT_ID>'")
	}

	return cfg, nil
}

// getFromKeychain retrieves a value from macOS Keychain using the security CLI
func getFromKeychain(account string) (string, error) {
	serviceName := "com.github.obsidian-outlook-sync"

	cmd := exec.Command("security", "find-generic-password",
		"-s", serviceName,
		"-a", account,
		"-w") // Print password only

	output, err := cmd.Output()
	if err != nil {
		// Exit code 44 means item not found (not an error, just not present)
		if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 44 {
			return "", nil
		}
		// Exit code 36 means user denied access
		if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 36 {
			return "", fmt.Errorf("Keychain access denied. Please grant access to the keychain or use environment variables")
		}
		return "", fmt.Errorf("failed to read from Keychain: %w", err)
	}

	return strings.TrimSpace(string(output)), nil
}
