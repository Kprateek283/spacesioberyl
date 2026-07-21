package tests

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
)

// Wave 2 (auth correctness) regression tests. Each maps to a backend-bugs item
// and fails against the pre-fix server. They run against the live seeded API on
// :8080, like the rest of this package, and skip nothing — a missing server
// surfaces as a failed request, which is the intended signal here.

// loginAs returns an access token for the given seeded account. Unlike the
// cached super-admin helper it always mints fresh, so lifecycle tests get their
// own refresh-token family and do not disturb other tests.
func loginAs(t *testing.T, email string) (access, refresh string) {
	t.Helper()
	body, _ := json.Marshal(map[string]string{"email": email, "password": seedPassword})
	resp, err := http.Post("http://localhost:8080/api/v1/login", "application/json", bytes.NewBuffer(body))
	if err != nil {
		t.Fatalf("login %s: %v", email, err)
	}
	defer resp.Body.Close()
	var res map[string]any
	json.NewDecoder(resp.Body).Decode(&res)
	a, _ := res["access_token"].(string)
	r, _ := res["refresh_token"].(string)
	if a == "" || r == "" {
		t.Fatalf("login %s returned no tokens (status %d): %v", email, resp.StatusCode, res)
	}
	return a, r
}

// adminAccessToken returns a cached admin access token, so the create-user tests
// share one login rather than each spending one against the per-IP login limiter.
func adminAccessToken(t *testing.T) string {
	return cachedToken(t, "admin-access", func() string {
		a, _ := loginAs(t, "admin@spacesio.test")
		return a
	})
}

func postJSON(t *testing.T, path, token string, payload any) *http.Response {
	t.Helper()
	body, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", "http://localhost:8080/api/v1"+path, bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST %s: %v", path, err)
	}
	return resp
}

// TestPrivilegeEscalationBlocked covers #10: an admin must not be able to create
// a super_admin, but may create lower roles.
func TestPrivilegeEscalationBlocked(t *testing.T) {
	adminToken := adminAccessToken(t)

	resp := postJSON(t, "/users", adminToken, map[string]string{
		"name": "Escalation Attempt", "email": "escalate@wave2.test",
		"password": seedPassword, "role": "super_admin", "department": "management",
	})
	resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("admin creating super_admin: got %d, want 403", resp.StatusCode)
	}

	// The same admin creating a staff account is allowed (201) or already exists
	// from a previous run (409). Anything else means the guard is too broad.
	resp = postJSON(t, "/users", adminToken, map[string]string{
		"name": "Legit Staff", "email": "legit@wave2.test",
		"password": seedPassword, "role": "staff", "department": "sales",
	})
	resp.Body.Close()
	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusConflict {
		t.Errorf("admin creating staff: got %d, want 201 or 409", resp.StatusCode)
	}
}

// TestWeakPasswordRejected covers #9: the validate tags are now enforced, so a
// short password is rejected before any row is written.
func TestWeakPasswordRejected(t *testing.T) {
	adminToken := adminAccessToken(t)

	resp := postJSON(t, "/users", adminToken, map[string]string{
		"name": "Weak", "email": "weak@wave2.test",
		"password": "abc", "role": "staff", "department": "sales",
	})
	resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("create user with 3-char password: got %d, want 400", resp.StatusCode)
	}
}

// TestRefreshRotationAndReuse covers #8: a refresh token rotates on use, and
// presenting an already-rotated token is detected as reuse and revokes the family.
func TestRefreshRotationAndReuse(t *testing.T) {
	_, rt := loginAs(t, "sales@spacesio.test")

	// First refresh succeeds and yields a new refresh token.
	resp := postJSON(t, "/refresh", "", map[string]string{"refresh_token": rt})
	var first map[string]any
	json.NewDecoder(resp.Body).Decode(&first)
	resp.Body.Close()
	rt2, _ := first["refresh_token"].(string)
	if rt2 == "" {
		t.Fatalf("first refresh returned no new refresh token: %v", first)
	}

	// Reusing the original (now rotated) token must be rejected.
	resp = postJSON(t, "/refresh", "", map[string]string{"refresh_token": rt})
	resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("reusing rotated refresh token: got %d, want 401", resp.StatusCode)
	}

	// Reuse detection revokes the whole family, so the rotated token is dead too.
	resp = postJSON(t, "/refresh", "", map[string]string{"refresh_token": rt2})
	resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("rotated token after reuse detection: got %d, want 401", resp.StatusCode)
	}
}

// TestLogoutRevokesRefreshToken covers #7: after logout the refresh token can no
// longer mint a new session.
func TestLogoutRevokesRefreshToken(t *testing.T) {
	access, rt := loginAs(t, "ops@spacesio.test")

	// Sanity: the refresh token works before logout.
	resp := postJSON(t, "/refresh", "", map[string]string{"refresh_token": rt})
	var res map[string]any
	json.NewDecoder(resp.Body).Decode(&res)
	resp.Body.Close()
	rt2, _ := res["refresh_token"].(string)
	if rt2 == "" {
		t.Fatalf("pre-logout refresh should succeed: %v", res)
	}

	resp = postJSON(t, "/logout", access, map[string]string{})
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("logout: got %d, want 200", resp.StatusCode)
	}

	// After logout, the rotated refresh token is revoked.
	resp = postJSON(t, "/refresh", "", map[string]string{"refresh_token": rt2})
	resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("refresh after logout: got %d, want 401", resp.StatusCode)
	}
}

// TestLoginRateLimitIgnoresForwardedHeader covers #4: RealIP is gone, so a client
// cannot rotate X-Forwarded-For to escape the per-IP limiter. This test floods
// the login endpoint, so it is intentionally the last auth test to run.
func TestLoginRateLimitIgnoresForwardedHeader(t *testing.T) {
	var limited bool
	for i := 0; i < 20; i++ {
		body, _ := json.Marshal(map[string]string{"email": "nobody@wave2.test", "password": "wrong"})
		req, _ := http.NewRequest("POST", "http://localhost:8080/api/v1/login", bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Forwarded-For", fmt.Sprintf("10.0.0.%d", i)) // spoof a fresh IP each time
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("login attempt %d: %v", i, err)
		}
		resp.Body.Close()
		if resp.StatusCode == http.StatusTooManyRequests {
			limited = true
			break
		}
	}
	if !limited {
		t.Error("20 login attempts with rotating X-Forwarded-For were never rate limited — RealIP is still trusting the header")
	}
}
