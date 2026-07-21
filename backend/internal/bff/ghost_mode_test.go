package bff

import (
	"context"
	"strings"
	"testing"

	"github.com/spacesioberyl/system-v1/internal/middleware"
)

// ghostCtx returns a context carrying claims with the given ghost-mode state,
// as RequireAuth would inject them.
func ghostCtx(role string, ghost bool) context.Context {
	return context.WithValue(context.Background(), middleware.ClaimsKey,
		&middleware.TokenClaims{UserID: 1, Role: role, TokenType: "access", GhostMode: ghost})
}

// TestCashFilterDirection pins the backend contract: ghost_mode == true means
// cash is VISIBLE. The Flutter client implements the opposite and is being
// fixed separately (backend-bugs.md #3). If this test fails, do not "fix" the
// backend to match a client — the backend is the canonical contract.
func TestCashFilterDirection(t *testing.T) {
	if got := cashFilter(ghostCtx("super_admin", true), "payment_term_type"); got != "" {
		t.Errorf("ghost mode ON must not filter cash, got %q — the direction has been inverted", got)
	}

	if got := cashFilter(ghostCtx("super_admin", false), "payment_term_type"); !strings.Contains(got, "!= 'cash'") {
		t.Errorf("ghost mode OFF must hide cash, got %q", got)
	}
}

// TestCashFilterFailsClosed covers the callers that hold no ghost-mode claim:
// they must see online payments only, never cash.
func TestCashFilterFailsClosed(t *testing.T) {
	cases := []struct {
		name string
		ctx  context.Context
	}{
		{"no claims at all", context.Background()},
		{"staff without ghost mode", ghostCtx("staff", false)},
		{"admin without ghost mode", ghostCtx("admin", false)},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := cashFilter(tc.ctx, "payment_term_type"); !strings.Contains(got, "!= 'cash'") {
				t.Errorf("must hide cash, got %q — the filter fails open", got)
			}
		})
	}
}

// TestCashFilterQualifiesColumn guards the aliased-column call sites: the
// pipeline and order queries join multiple tables, so an unqualified column
// would be ambiguous SQL.
func TestCashFilterQualifiesColumn(t *testing.T) {
	got := cashFilter(context.Background(), "o.payment_term_type")
	if !strings.Contains(got, "o.payment_term_type != 'cash'") {
		t.Errorf("column qualifier must be preserved, got %q", got)
	}
}
