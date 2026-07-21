package tests

import (
	"strings"
	"testing"

	"github.com/spacesioberyl/system-v1/internal/config"
)

// TestJWTSecretValidation covers backend-bugs.md #5: the API used to boot with
// an unset JWT_SECRET and sign every token with an empty HMAC key, letting
// anyone forge a super_admin + ghost_mode token.
func TestJWTSecretValidation(t *testing.T) {
	cases := []struct {
		name      string
		secret    string
		wantError bool
	}{
		{"unset secret is rejected", "", true},
		{"short secret is rejected", "tooshort", true},
		{"one byte under the minimum is rejected", strings.Repeat("x", config.MinJWTSecretLen-1), true},
		{"secret at the minimum is accepted", strings.Repeat("x", config.MinJWTSecretLen), false},
		{"long secret is accepted", strings.Repeat("x", 64), false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			// The other required secrets are supplied so this isolates JWT_SECRET.
			cfg := &config.Config{
				JWTSecret:      tc.secret,
				DatabaseURL:    "postgres://x",
				MinIOAccessKey: "k",
				MinIOSecretKey: "s",
			}
			err := cfg.Validate()
			if tc.wantError && err == nil {
				t.Errorf("Validate() accepted a %d-byte secret, want rejection", len(tc.secret))
			}
			if !tc.wantError && err != nil {
				t.Errorf("Validate() rejected a %d-byte secret: %v", len(tc.secret), err)
			}
		})
	}
}

// TestRequiredSecretsValidation covers backend-bugs.md #25: secrets have no
// defaults, so an unset DATABASE_URL or MinIO credential must fail at boot
// rather than fall back to a shipped credential.
func TestRequiredSecretsValidation(t *testing.T) {
	goodSecret := strings.Repeat("x", config.MinJWTSecretLen)
	base := func() *config.Config {
		return &config.Config{
			JWTSecret:      goodSecret,
			DatabaseURL:    "postgres://x",
			MinIOAccessKey: "k",
			MinIOSecretKey: "s",
		}
	}
	if err := base().Validate(); err != nil {
		t.Fatalf("fully-populated config rejected: %v", err)
	}

	missingDB := base()
	missingDB.DatabaseURL = ""
	if missingDB.Validate() == nil {
		t.Error("Validate() accepted an empty DATABASE_URL, want rejection")
	}

	missingMinIO := base()
	missingMinIO.MinIOSecretKey = ""
	if missingMinIO.Validate() == nil {
		t.Error("Validate() accepted an empty MINIO_SECRET_KEY, want rejection")
	}
}
