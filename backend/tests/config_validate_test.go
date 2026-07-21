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
			err := (&config.Config{JWTSecret: tc.secret}).Validate()
			if tc.wantError && err == nil {
				t.Errorf("Validate() accepted a %d-byte secret, want rejection", len(tc.secret))
			}
			if !tc.wantError && err != nil {
				t.Errorf("Validate() rejected a %d-byte secret: %v", len(tc.secret), err)
			}
		})
	}
}
