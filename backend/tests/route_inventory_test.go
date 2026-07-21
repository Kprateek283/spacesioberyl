package tests

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/app"
	"github.com/spacesioberyl/system-v1/internal/config"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

// publicRoutes is the complete set of endpoints that may be reached without a
// valid access token. Everything else the router exposes must return 401.
//
// Adding a route to this set is a security decision — it means anyone who can
// reach the port can call it. Do not add an entry to silence a failing test.
var publicRoutes = map[string]bool{
	"GET /ping":                    true,
	"POST /api/v1/login":           true,
	"POST /api/v1/refresh":         true,
	"POST /api/v1/password/forgot": true,
	"POST /api/v1/password/reset":  true,
}

// protectedRoutes is every route that must reject an anonymous caller.
// It is written out in full rather than derived, so that a newly registered
// endpoint fails TestRouteInventory until someone classifies it deliberately.
var protectedRoutes = []string{
	// IAM
	"POST /api/v1/logout",
	"GET /api/v1/users/me",
	"PATCH /api/v1/users/me/password",
	"GET /api/v1/users",
	"POST /api/v1/users",
	"PATCH /api/v1/users/{id}/status",
	"POST /api/v1/iam/verify-pin",
	"POST /api/v1/iam/setup-pins",

	// HR — attendance
	"POST /api/v1/hr/attendance/check-in",
	"POST /api/v1/hr/attendance/check-out",
	"GET /api/v1/hr/attendance/me",
	"GET /api/v1/hr/attendance/",
	"GET /api/v1/hr/attendance/overrides",
	"PATCH /api/v1/hr/attendance/overrides/{id}",

	// HR — expenses
	"POST /api/v1/hr/expenses/",
	"GET /api/v1/hr/expenses/",
	"GET /api/v1/hr/expenses/{id}",

	// HR — leaves
	"POST /api/v1/hr/leaves/",
	"GET /api/v1/hr/leaves/me",
	"PATCH /api/v1/hr/leaves/{id}",
	"PATCH /api/v1/hr/leaves/{id}/cancel",
	"GET /api/v1/hr/leaves/",
	"PATCH /api/v1/hr/leaves/{id}/admin-edit",
	"PATCH /api/v1/hr/leaves/{id}/status",

	// CRM — leads and quotations
	"POST /api/v1/crm/leads/",
	"GET /api/v1/crm/leads/",
	"GET /api/v1/crm/leads/{id}",
	"PATCH /api/v1/crm/leads/{id}/status",
	"PATCH /api/v1/crm/leads/{id}/assign",
	"POST /api/v1/crm/leads/{id}/quotations",
	"GET /api/v1/crm/leads/{id}/quotations",
	"PATCH /api/v1/crm/quotations/{id}/status",

	// CRM — follow-ups and complaints
	"POST /api/v1/crm/followups/",
	"GET /api/v1/crm/followups/my-queue",
	"PATCH /api/v1/crm/followups/{id}/complete",
	"POST /api/v1/crm/complaints/",
	"GET /api/v1/crm/complaints/",
	"PATCH /api/v1/crm/complaints/{id}/assign",
	"PATCH /api/v1/crm/complaints/{id}/status",

	// Logistics
	"GET /api/v1/logistics/vendors/",
	"GET /api/v1/logistics/vendors/{id}",
	"POST /api/v1/logistics/vendors/",
	"GET /api/v1/logistics/orders/",
	"PATCH /api/v1/logistics/orders/{id}/assign",
	"POST /api/v1/logistics/orders/{id}/pos",
	"POST /api/v1/logistics/dispatches/",
	"GET /api/v1/logistics/dispatches/my-tasks",
	"PATCH /api/v1/logistics/dispatches/{id}/log",

	// Execution
	"POST /api/v1/execution/installers/",
	"GET /api/v1/execution/installers/",
	"GET /api/v1/execution/jobs/",
	"GET /api/v1/execution/jobs/my-tasks",
	"PATCH /api/v1/execution/jobs/{id}/assign",
	"POST /api/v1/execution/jobs/{id}/updates/sync",
	"GET /api/v1/execution/jobs/{id}/updates",
	"PATCH /api/v1/execution/jobs/{id}/signoff",
	"POST /api/v1/execution/orders/{id}/installation",
	"PATCH /api/v1/execution/contractors/jobs/{id}/status",
	"POST /api/v1/execution/contractors/jobs/{id}/check-in",
	"POST /api/v1/execution/contractors/jobs/{id}/check-out",
	"POST /api/v1/execution/contractors/jobs/{id}/payments",
	"GET /api/v1/execution/contractors/jobs/{id}/ledger",

	// BFF — these five were unauthenticated until backend-bugs.md #1
	"GET /api/v1/projects/pipeline",
	"GET /api/v1/projects/{id}/details",
	"POST /api/v1/projects/{id}/docs",
	"GET /api/v1/workspace/action-items",
	"GET /api/v1/workspace/personal-timeline",
}

// buildTestRouter wires the real application router. The pool is never
// connected: an anonymous request is rejected by the auth middleware long
// before any handler reaches the database.
func buildTestRouter(t *testing.T) *chi.Mux {
	t.Helper()
	logger.Init()

	pool, err := pgxpool.New(context.Background(), "postgres://unused:unused@127.0.0.1:1/unused")
	if err != nil {
		t.Fatalf("building an unconnected pool should not fail: %v", err)
	}
	t.Cleanup(pool.Close)

	cfg := &config.Config{JWTSecret: strings.Repeat("x", config.MinJWTSecretLen)}
	return app.New(pool, cfg).Router
}

// TestRouteInventory asserts that the router exposes exactly the routes we
// have classified — no more, no less. A new endpoint fails this test until it
// is added to publicRoutes or protectedRoutes, which forces the auth tier to
// be an explicit decision rather than an oversight.
func TestRouteInventory(t *testing.T) {
	expected := map[string]bool{}
	for k := range publicRoutes {
		expected[k] = true
	}
	for _, k := range protectedRoutes {
		expected[k] = true
	}

	found := map[string]bool{}
	err := chi.Walk(buildTestRouter(t), func(method, route string, _ http.Handler, _ ...func(http.Handler) http.Handler) error {
		found[method+" "+strings.TrimSuffix(route, "/*")] = true
		return nil
	})
	if err != nil {
		t.Fatalf("walking the router: %v", err)
	}

	for route := range found {
		if !expected[route] {
			t.Errorf("unclassified route %q: add it to publicRoutes or protectedRoutes in this file, choosing its auth tier deliberately", route)
		}
	}
	for route := range expected {
		if !found[route] {
			t.Errorf("route %q is classified here but no longer registered: remove it from this file if the removal was intended", route)
		}
	}
}

// TestProtectedRoutesRejectAnonymous fires a tokenless request at every
// protected route and requires a 401. This is the regression that
// backend-bugs.md #1 (unauthenticated BFF) and #13 (open POC ping) describe.
func TestProtectedRoutesRejectAnonymous(t *testing.T) {
	router := buildTestRouter(t)

	for _, route := range protectedRoutes {
		t.Run(route, func(t *testing.T) {
			method, pattern, ok := strings.Cut(route, " ")
			if !ok {
				t.Fatalf("malformed route entry %q, want \"METHOD /path\"", route)
			}

			// Substitute a concrete value for path parameters so the request routes.
			path := strings.NewReplacer("{id}", "1").Replace(pattern)

			req := httptest.NewRequest(method, path, nil)
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, req)

			if rec.Code != http.StatusUnauthorized {
				t.Errorf("anonymous %s %s returned %d, want 401 — this endpoint is reachable without a token", method, path, rec.Code)
			}
		})
	}
}
