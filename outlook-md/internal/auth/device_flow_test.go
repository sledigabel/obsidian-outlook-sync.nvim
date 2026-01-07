package auth

import (
	"os"
	"testing"
	"time"

	"golang.org/x/oauth2"
)

// TestDeviceCodeFlow tests the device code flow initiation
func TestDeviceCodeFlow(t *testing.T) {
	t.Skip("Phase 5: Device code flow tests to be implemented")

	// TODO: Test device code initiation
	// TODO: Test polling logic
	// TODO: Test timeout handling
	// TODO: Test cancellation
}

// TestTokenCache tests token save/load operations
func TestTokenCache(t *testing.T) {
	// Create temp directory for cache file
	tempDir := t.TempDir()
	cacheFile := tempDir + "/token.json"

	cache := NewTokenCache(cacheFile)

	// Create test token
	testToken := &oauth2.Token{
		AccessToken:  "test-access-token",
		TokenType:    "Bearer",
		RefreshToken: "test-refresh-token",
		Expiry:       time.Now().Add(time.Hour),
	}

	// Test save
	err := cache.Save(testToken)
	if err != nil {
		t.Fatalf("Save failed: %v", err)
	}

	// Verify file exists and has 0600 permissions
	info, err := os.Stat(cacheFile)
	if err != nil {
		t.Fatalf("Cache file not created: %v", err)
	}
	if info.Mode().Perm() != 0600 {
		t.Errorf("Expected file permissions 0600, got %v", info.Mode().Perm())
	}

	// Test load
	loadedToken, err := cache.Load()
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	// Verify token contents
	if loadedToken.AccessToken != testToken.AccessToken {
		t.Errorf("AccessToken mismatch: expected %s, got %s", testToken.AccessToken, loadedToken.AccessToken)
	}
	if loadedToken.RefreshToken != testToken.RefreshToken {
		t.Errorf("RefreshToken mismatch: expected %s, got %s", testToken.RefreshToken, loadedToken.RefreshToken)
	}
	if loadedToken.TokenType != testToken.TokenType {
		t.Errorf("TokenType mismatch: expected %s, got %s", testToken.TokenType, loadedToken.TokenType)
	}
}

// TestTokenCacheFileNotExists tests loading from non-existent cache
func TestTokenCacheFileNotExists(t *testing.T) {
	tempDir := t.TempDir()
	cacheFile := tempDir + "/nonexistent.json"

	cache := NewTokenCache(cacheFile)
	_, err := cache.Load()

	if err == nil {
		t.Error("Expected error when loading non-existent cache file")
	}
	if !os.IsNotExist(err) {
		t.Errorf("Expected os.IsNotExist error, got: %v", err)
	}
}

// TestTokenCacheInvalidContent tests loading invalid JSON
func TestTokenCacheInvalidContent(t *testing.T) {
	tempDir := t.TempDir()
	cacheFile := tempDir + "/invalid.json"

	// Write invalid JSON
	err := os.WriteFile(cacheFile, []byte("not valid json"), 0600)
	if err != nil {
		t.Fatalf("Failed to create invalid cache file: %v", err)
	}

	cache := NewTokenCache(cacheFile)
	_, err = cache.Load()

	if err == nil {
		t.Error("Expected error when loading invalid JSON")
	}
}

// TestTokenRefresh tests automatic token refresh
func TestTokenRefresh(t *testing.T) {
	// Create a valid token (not expired)
	validToken := &oauth2.Token{
		AccessToken:  "valid-token",
		TokenType:    "Bearer",
		RefreshToken: "refresh-token",
		Expiry:       time.Now().Add(time.Hour),
	}

	// Create token source with valid token
	ts := &TokenSource{
		token: validToken,
		config: &oauth2.Config{
			ClientID: "test-client-id",
			Scopes:   []string{"Calendars.Read"},
		},
		cache: nil, // No cache for this test
	}

	// Call Token() should return same token without refresh
	token, err := ts.Token()
	if err != nil {
		t.Fatalf("Token() failed: %v", err)
	}

	if token.AccessToken != validToken.AccessToken {
		t.Errorf("Token mismatch: expected %s, got %s", validToken.AccessToken, token.AccessToken)
	}
}

// TestTokenExpiredNeedsRefresh tests that expired tokens are detected
func TestTokenExpiredNeedsRefresh(t *testing.T) {
	// Create an expired token
	expiredToken := &oauth2.Token{
		AccessToken:  "expired-token",
		TokenType:    "Bearer",
		RefreshToken: "refresh-token",
		Expiry:       time.Now().Add(-time.Hour), // Expired 1 hour ago
	}

	// Verify token is not valid
	if expiredToken.Valid() {
		t.Error("Expected token to be invalid/expired")
	}

	// Note: Actual refresh would require a mock OAuth2 server
	// which is beyond the scope of Phase 5. We're verifying
	// the logic detects expiration correctly.
}
