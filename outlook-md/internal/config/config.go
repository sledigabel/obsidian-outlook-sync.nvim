package config

import (
	"fmt"
	"os"
)

// Config holds application configuration
type Config struct {
	ClientID string
	TenantID string
}

// Load loads configuration from Keychain (macOS) or environment variables
// Priority: 1) Keychain (macOS only), 2) Environment variables
func Load() (*Config, error) {
	cfg := &Config{}

	// Try to load from Keychain first (macOS only, via build tags)
	if keychainAvailable() {
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
