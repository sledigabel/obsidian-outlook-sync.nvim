package auth

import (
	"encoding/json"
	"fmt"
	"os"

	"golang.org/x/oauth2"
)

// TokenCache handles persistent storage of OAuth2 tokens
type TokenCache struct {
	filePath string
}

// NewTokenCache creates a new token cache with the specified file path
func NewTokenCache(filePath string) *TokenCache {
	return &TokenCache{
		filePath: filePath,
	}
}

// Save writes the token to the cache file with 0600 permissions
func (tc *TokenCache) Save(token *oauth2.Token) error {
	// Marshal token to JSON
	data, err := json.MarshalIndent(token, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal token: %w", err)
	}

	// Write to file with 0600 permissions (read/write for owner only)
	err = os.WriteFile(tc.filePath, data, 0600)
	if err != nil {
		return fmt.Errorf("failed to write token cache: %w", err)
	}

	return nil
}

// Load reads the token from the cache file
func (tc *TokenCache) Load() (*oauth2.Token, error) {
	// Read file contents
	data, err := os.ReadFile(tc.filePath)
	if err != nil {
		return nil, err // Return raw error so caller can check os.IsNotExist
	}

	// Unmarshal JSON to token
	var token oauth2.Token
	err = json.Unmarshal(data, &token)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal token: %w", err)
	}

	return &token, nil
}
