package auth

import (
	"context"
	"fmt"
	"os"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/microsoft"
)

// DeviceCodeAuthenticator handles OAuth2 device code flow
type DeviceCodeAuthenticator struct {
	clientID string
	tenantID string
	scopes   []string
}

// NewDeviceCodeAuthenticator creates a new device code authenticator
func NewDeviceCodeAuthenticator(clientID, tenantID string) *DeviceCodeAuthenticator {
	return &DeviceCodeAuthenticator{
		clientID: clientID,
		tenantID: tenantID,
		scopes: []string{
			"Calendars.Read",
			"offline_access",
		},
	}
}

// Authenticate performs device code flow and returns a token
func (a *DeviceCodeAuthenticator) Authenticate(ctx context.Context) (*oauth2.Token, error) {
	// Configure OAuth2 endpoint for Microsoft
	endpoint := microsoft.AzureADEndpoint(a.tenantID)

	config := &oauth2.Config{
		ClientID: a.clientID,
		Scopes:   a.scopes,
		Endpoint: endpoint,
	}

	// Initiate device code flow
	deviceCode, err := config.DeviceAuth(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to initiate device code flow: %w", err)
	}

	// Display instructions to user on stderr
	fmt.Fprintf(os.Stderr, "\nTo authenticate:\n")
	fmt.Fprintf(os.Stderr, "1. Visit: %s\n", deviceCode.VerificationURI)
	fmt.Fprintf(os.Stderr, "2. Enter code: %s\n", deviceCode.UserCode)
	fmt.Fprintf(os.Stderr, "\nWaiting for authentication...\n\n")

	// Poll for completion
	token, err := config.DeviceAccessToken(ctx, deviceCode)
	if err != nil {
		return nil, fmt.Errorf("device code flow failed: %w", err)
	}

	fmt.Fprintf(os.Stderr, "✓ Authentication successful!\n\n")

	return token, nil
}

// TokenSource wraps a token and provides automatic refresh
type TokenSource struct {
	token  *oauth2.Token
	config *oauth2.Config
	cache  *TokenCache
}

// NewTokenSource creates a token source with automatic refresh
func NewTokenSource(token *oauth2.Token, clientID, tenantID string, cache *TokenCache) *TokenSource {
	endpoint := microsoft.AzureADEndpoint(tenantID)

	config := &oauth2.Config{
		ClientID: clientID,
		Scopes: []string{
			"Calendars.Read",
			"offline_access",
		},
		Endpoint: endpoint,
	}

	return &TokenSource{
		token:  token,
		config: config,
		cache:  cache,
	}
}

// Token returns a valid token, refreshing if necessary
func (ts *TokenSource) Token() (*oauth2.Token, error) {
	// Check if token needs refresh
	if ts.token.Valid() {
		return ts.token, nil
	}

	// Refresh token
	ctx := context.Background()
	newToken, err := ts.config.TokenSource(ctx, ts.token).Token()
	if err != nil {
		return nil, fmt.Errorf("failed to refresh token: %w", err)
	}

	// Update stored token
	ts.token = newToken

	// Save refreshed token to cache
	if ts.cache != nil {
		if err := ts.cache.Save(newToken); err != nil {
			// Log warning but don't fail
			fmt.Fprintf(os.Stderr, "Warning: failed to save refreshed token: %v\n", err)
		}
	}

	return newToken, nil
}
