package tests

import (
	"bytes"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"strings"
	"testing"
)

// Wave 3 regression tests for object storage (#12/#31) and request-body bounding
// (#19). They run against the live seeded stack on :8080 and reuse the cached
// super-admin token so they cost no extra login against the rate limiter.

// uploadDoc posts a one-part multipart form to the project docs endpoint.
func uploadDoc(t *testing.T, token, filename, contentType string) *http.Response {
	t.Helper()
	var body bytes.Buffer
	mw := multipart.NewWriter(&body)
	_ = mw.WriteField("document_type", "test")
	part, err := mw.CreatePart(map[string][]string{
		"Content-Disposition": {`form-data; name="file"; filename="` + filename + `"`},
		"Content-Type":        {contentType},
	})
	if err != nil {
		t.Fatalf("build multipart: %v", err)
	}
	part.Write([]byte("dummy file bytes"))
	mw.Close()

	req, _ := http.NewRequest("POST", "http://localhost:8080/api/v1/projects/1/docs", &body)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("upload %s: %v", filename, err)
	}
	return resp
}

// TestUploadRejectsDisallowedExtension covers #31: the extension allowlist is
// enforced and a disallowed type is a 400 client error (not a 500).
func TestUploadRejectsDisallowedExtension(t *testing.T) {
	token := getBaseToken(t)
	resp := uploadDoc(t, token, "evil.html", "text/html")
	resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("uploading .html: got %d, want 400", resp.StatusCode)
	}
}

// TestUploadedFileRequiresAuth covers #12: an uploaded file is stored under the
// authenticated /api/v1/files endpoint (not a public bucket URL), so it is
// reachable with a token and rejected without one.
func TestUploadedFileRequiresAuth(t *testing.T) {
	token := getBaseToken(t)
	resp := uploadDoc(t, token, "doc.pdf", "application/pdf")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("uploading .pdf: got %d, want 201", resp.StatusCode)
	}
	var doc struct {
		FileURL string `json:"file_url"`
	}
	json.NewDecoder(resp.Body).Decode(&doc)
	if !strings.HasPrefix(doc.FileURL, "/api/v1/files/") {
		t.Fatalf("file_url %q should route through the authenticated file endpoint, not a public URL", doc.FileURL)
	}

	// With a token, the file streams back.
	req, _ := http.NewRequest("GET", "http://localhost:8080"+doc.FileURL, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	authed, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("authed fetch: %v", err)
	}
	authed.Body.Close()
	if authed.StatusCode != http.StatusOK {
		t.Errorf("authed file fetch: got %d, want 200", authed.StatusCode)
	}

	// Without a token, it is refused — the object is no longer public.
	anon, err := http.Get("http://localhost:8080" + doc.FileURL)
	if err != nil {
		t.Fatalf("anon fetch: %v", err)
	}
	anon.Body.Close()
	if anon.StatusCode != http.StatusUnauthorized {
		t.Errorf("anonymous file fetch: got %d, want 401", anon.StatusCode)
	}
}

// TestRequestBodyLimited covers #19: an oversized body is rejected rather than
// read unbounded into memory. It targets /refresh, which has no per-IP limiter,
// so the result is the body-limit rejection and not a 429.
func TestRequestBodyLimited(t *testing.T) {
	big := bytes.Repeat([]byte("a"), 12<<20) // 12 MB, above the 11 MB cap
	payload, _ := json.Marshal(map[string]string{"refresh_token": string(big)})
	resp, err := http.Post("http://localhost:8080/api/v1/refresh", "application/json", bytes.NewReader(payload))
	if err != nil {
		t.Fatalf("oversized refresh: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusTooManyRequests {
		t.Errorf("oversized body: got %d, want a 4xx rejection (400/413)", resp.StatusCode)
	}
}
