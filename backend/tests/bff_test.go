package tests

import (
	"encoding/json"
	"net/http"
	"testing"
)

// TestBFFPipelineAPI tests the GET /api/v1/projects/pipeline endpoint
func TestBFFPipelineAPI(t *testing.T) {
	resp, err := http.Get("http://localhost:8080/api/v1/projects/pipeline")
	if err != nil {
		t.Fatalf("Expected no error connecting to server, got %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Expected status OK, got %v", resp.StatusCode)
	}

	var data map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&data)
	if _, ok := data["leads"]; !ok {
		t.Errorf("Expected leads key in response")
	}
}

// TestBFFActionItemsAPI tests the GET /api/v1/workspace/action-items endpoint
func TestBFFActionItemsAPI(t *testing.T) {
	resp, err := http.Get("http://localhost:8080/api/v1/workspace/action-items")
	if err != nil {
		t.Fatalf("Expected no error connecting to server, got %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Expected status OK, got %v", resp.StatusCode)
	}

	var data map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&data)
	if _, ok := data["items"]; !ok {
		t.Errorf("Expected items key in response")
	}
}
