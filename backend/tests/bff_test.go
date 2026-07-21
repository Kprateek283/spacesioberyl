package tests

import (
	"net/http"
	"testing"
)

// These are live-server smoke tests. They previously asserted that the BFF
// endpoints returned 200 to an anonymous caller, which encoded backend-bugs.md
// #1 (the entire BFF module was unauthenticated) as expected behaviour. They now
// assert the opposite. The hermetic equivalent, which needs no running server,
// is TestProtectedRoutesRejectAnonymous in route_inventory_test.go.

// getOrSkip performs a GET against the local API, skipping the test when no
// server is listening so that `go test ./...` is usable without docker up.
func getOrSkip(t *testing.T, url string) *http.Response {
	t.Helper()
	resp, err := http.Get(url)
	if err != nil {
		t.Skipf("no API server on localhost:8080, skipping live smoke test: %v", err)
	}
	return resp
}

// TestBFFPipelineRequiresAuth asserts GET /api/v1/projects/pipeline rejects anonymous callers.
func TestBFFPipelineRequiresAuth(t *testing.T) {
	resp := getOrSkip(t, "http://localhost:8080/api/v1/projects/pipeline")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("anonymous pipeline request returned %d, want 401 — the pipeline exposes approved quotation values", resp.StatusCode)
	}
}

// TestBFFActionItemsRequiresAuth asserts GET /api/v1/workspace/action-items rejects anonymous callers.
func TestBFFActionItemsRequiresAuth(t *testing.T) {
	resp := getOrSkip(t, "http://localhost:8080/api/v1/workspace/action-items")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("anonymous action-items request returned %d, want 401", resp.StatusCode)
	}
}
