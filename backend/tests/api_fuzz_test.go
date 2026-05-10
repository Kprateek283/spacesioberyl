package tests

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"testing"
)

func FuzzCreateComplaintAPI(f *testing.F) {
	// Add seed corpus
	f.Add("Broken sink", "Sink is leaking from the bottom pipe", "high")
	f.Add("AC issue", "Not cooling properly in the main hall", "medium")
	f.Add("Door hinge loose", "Cabinet door hinge is very loose", "low")
	f.Add("", "", "") // Empty strings
	f.Add("A", "B", "critical") // Edge case short strings

	f.Fuzz(func(t *testing.T, title, desc, priority string) {
		// Since fuzzing runs a large number of times, we must not hit the real API
        // unconditionally without rate limiting or we might overwhelm our local docker.
        // However, for this exercise, we will just fetch the token once and use it.
        // We will skip if the token isn't easily accessible to avoid test hang.
        token := getPINToken(t, getBaseToken(t), "1234")

		payload := map[string]interface{}{
			"title":       title,
			"description": desc,
			"priority":    priority,
			"lead_id":     1,
		}
		body, _ := json.Marshal(payload)
		req, _ := http.NewRequest("POST", "http://localhost:8080/api/v1/crm/complaints", bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)

		client := &http.Client{}
		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("Request failed: %v", err)
		}
		defer resp.Body.Close()
		io.ReadAll(resp.Body) // Drain body to reuse connection

		// The key assertion in fuzzing an API endpoint is that it should NEVER panic or return 500
		// A 400 Bad Request is perfectly fine for invalid input.
		if resp.StatusCode == http.StatusInternalServerError {
			t.Errorf("Fuzzed input caused 500 Internal Server Error: title=%q, desc=%q, priority=%q", title, desc, priority)
		}
	})
}
