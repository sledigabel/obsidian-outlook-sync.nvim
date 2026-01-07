// +build !darwin

package config

// getFromKeychain is a stub for non-macOS systems
// Always returns empty string (Keychain not available)
func getFromKeychain(account string) (string, error) {
	return "", nil
}

// keychainAvailable returns false on non-macOS systems
func keychainAvailable() bool {
	return false
}
