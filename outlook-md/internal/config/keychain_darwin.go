// +build darwin

package config

import (
	"fmt"
	"os/exec"
	"strings"
)

// getFromKeychain retrieves a value from macOS Keychain using the security CLI
// This function is only available on macOS (darwin)
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

// keychainAvailable returns true on macOS (where Keychain is available)
func keychainAvailable() bool {
	return true
}
