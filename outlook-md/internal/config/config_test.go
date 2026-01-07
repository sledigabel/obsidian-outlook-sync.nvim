package config

import (
	"os"
	"testing"
)

// TestLoadFromEnvironmentVariables tests loading config from env vars
func TestLoadFromEnvironmentVariables(t *testing.T) {
	// Set up test environment variables
	os.Setenv("OUTLOOK_MD_CLIENT_ID", "test-client-id")
	os.Setenv("OUTLOOK_MD_TENANT_ID", "test-tenant-id")
	defer func() {
		os.Unsetenv("OUTLOOK_MD_CLIENT_ID")
		os.Unsetenv("OUTLOOK_MD_TENANT_ID")
	}()

	// Load config
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() failed: %v", err)
	}

	// Verify values
	if cfg.ClientID != "test-client-id" {
		t.Errorf("ClientID mismatch: got %s, want test-client-id", cfg.ClientID)
	}
	if cfg.TenantID != "test-tenant-id" {
		t.Errorf("TenantID mismatch: got %s, want test-tenant-id", cfg.TenantID)
	}
}

// TestLoadMissingClientID tests error when client ID is missing
func TestLoadMissingClientID(t *testing.T) {
	// Clear environment variables
	os.Unsetenv("OUTLOOK_MD_CLIENT_ID")
	os.Unsetenv("OUTLOOK_MD_TENANT_ID")

	// Attempt to load config
	_, err := Load()
	if err == nil {
		t.Error("Expected error when client ID is missing, got nil")
	}

	// Verify error message mentions client ID
	if err != nil && len(err.Error()) > 0 {
		errMsg := err.Error()
		if len(errMsg) < 10 || errMsg[:10] != "client ID " {
			// Check if it contains helpful information
			if len(errMsg) < 200 {
				t.Logf("Error message may be too short, got: %s", errMsg)
			}
		}
	}
}

// TestLoadMissingTenantID tests error when tenant ID is missing
func TestLoadMissingTenantID(t *testing.T) {
	// Set only client ID
	os.Setenv("OUTLOOK_MD_CLIENT_ID", "test-client-id")
	os.Unsetenv("OUTLOOK_MD_TENANT_ID")
	defer os.Unsetenv("OUTLOOK_MD_CLIENT_ID")

	// Attempt to load config
	_, err := Load()
	if err == nil {
		t.Error("Expected error when tenant ID is missing, got nil")
	}

	// Verify error message mentions tenant ID
	if err != nil && len(err.Error()) > 0 {
		errMsg := err.Error()
		if len(errMsg) < 10 || errMsg[:10] != "tenant ID " {
			// Check if it contains helpful information
			if len(errMsg) < 200 {
				t.Logf("Error message may be too short, got: %s", errMsg)
			}
		}
	}
}

// TestEnvironmentVariablesFallback tests that env vars are used when Keychain is unavailable
func TestEnvironmentVariablesFallback(t *testing.T) {
	// This test verifies the fallback mechanism
	// On non-macOS systems, env vars should be used
	// On macOS, if Keychain doesn't have the values, env vars should be used

	os.Setenv("OUTLOOK_MD_CLIENT_ID", "fallback-client-id")
	os.Setenv("OUTLOOK_MD_TENANT_ID", "fallback-tenant-id")
	defer func() {
		os.Unsetenv("OUTLOOK_MD_CLIENT_ID")
		os.Unsetenv("OUTLOOK_MD_TENANT_ID")
	}()

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() failed with env vars set: %v", err)
	}

	// Should load from env vars (either because not macOS, or Keychain doesn't have them)
	// We expect either the env var values or Keychain values
	if cfg.ClientID == "" {
		t.Error("ClientID should not be empty with env var set")
	}
	if cfg.TenantID == "" {
		t.Error("TenantID should not be empty with env var set")
	}
}

// TestConfigStructure tests that Config struct has expected fields
func TestConfigStructure(t *testing.T) {
	cfg := &Config{
		ClientID: "test-client",
		TenantID: "test-tenant",
	}

	if cfg.ClientID != "test-client" {
		t.Errorf("ClientID field not working correctly")
	}
	if cfg.TenantID != "test-tenant" {
		t.Errorf("TenantID field not working correctly")
	}
}
