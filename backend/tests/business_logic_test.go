package tests

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

func getBaseToken(t *testing.T) string {
	payload := map[string]string{
		"email":    "admin@company.com",
		"password": "newpass123",
	}
	body, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", "http://localhost:8080/api/v1/login", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("Base login failed: %v", err)
	}
	defer resp.Body.Close()

	var res map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&res)
	if token, ok := res["access_token"].(string); ok {
		return token
	}
	t.Fatalf("No token in login response")
	return ""
}

func getPINToken(t *testing.T, baseToken, pin string) string {
	payload := map[string]string{"pin": pin}
	body, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", "http://localhost:8080/api/v1/iam/verify-pin", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+baseToken)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("PIN verification failed: %v", err)
	}
	defer resp.Body.Close()

	var res map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&res)
	if token, ok := res["access_token"].(string); ok {
		return token
	}
	t.Fatalf("No token in PIN response")
	return ""
}

func TestGhostModeLogic(t *testing.T) {
	baseToken := getBaseToken(t)

	// In the seeded system, normal PIN is 1234, Ghost PIN is 567890
	normalToken := getPINToken(t, baseToken, "1234")
	ghostToken := getPINToken(t, baseToken, "567890")

	client := &http.Client{}

	// Test 1: Normal PIN should NOT see cash transactions
	req1, _ := http.NewRequest("GET", "http://localhost:8080/api/v1/crm/leads/1/quotations", nil)
	req1.Header.Set("Authorization", "Bearer "+normalToken)
	resp1, err := client.Do(req1)
	if err != nil {
		t.Fatalf("Failed to get quotations: %v", err)
	}
	defer resp1.Body.Close()
	body1, _ := io.ReadAll(resp1.Body)

	if strings.Contains(string(body1), `"payment_term_type":"cash"`) {
		t.Errorf("Ghost mode failure: Cash transaction IS visible using Normal PIN")
	}

	// Test 2: Ghost PIN SHOULD see cash transactions
	req2, _ := http.NewRequest("GET", "http://localhost:8080/api/v1/crm/leads/1/quotations", nil)
	req2.Header.Set("Authorization", "Bearer "+ghostToken)
	resp2, err := client.Do(req2)
	if err != nil {
		t.Fatalf("Failed to get quotations: %v", err)
	}
	defer resp2.Body.Close()
	body2, _ := io.ReadAll(resp2.Body)

	if !strings.Contains(string(body2), `"payment_term_type":"cash"`) {
		t.Errorf("Ghost mode failure: Cash transaction NOT visible using Ghost PIN")
	}
}

func TestHRLeaveStateLogic(t *testing.T) {
	token := getPINToken(t, getBaseToken(t), "1234")
	client := &http.Client{}

	// 1. Create a Leave
	payload := map[string]string{
		"leave_type": "sick_leave",
		"start_date": "2026-06-01",
		"end_date":   "2026-06-02",
		"reason":     "Test leave",
	}
	body, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", "http://localhost:8080/api/v1/hr/leaves", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("Failed to create leave: %v", err)
	}
	defer resp.Body.Close()

	var createRes map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&createRes)
	leaveIDFloat, ok := createRes["id"].(float64)
	if !ok {
		t.Fatalf("Failed to parse leave ID")
	}
	leaveID := int(leaveIDFloat)

	// 2. Admin Rejects Leave
	rejectPayload := map[string]string{"status": "rejected", "admin_remarks": "Not allowed"}
	rejectBody, _ := json.Marshal(rejectPayload)
	reqReject, _ := http.NewRequest("PATCH", "http://localhost:8080/api/v1/hr/leaves/"+string(rune(leaveID+'0'))+"/status", bytes.NewBuffer(rejectBody)) // simplistic string conversion
	reqReject.URL.Path = "/api/v1/hr/leaves/" + string(rune(leaveID+'0')) + "/status" // Fix URL building
    
    // Better string conversion
    leaveIDStr := ""
    if leaveID > 9 { t.Fatalf("Test only supports leave ID < 10 for simplicity") }
    leaveIDStr = string(rune('0' + leaveID))
    
    reqReject, _ = http.NewRequest("PATCH", "http://localhost:8080/api/v1/hr/leaves/"+leaveIDStr+"/status", bytes.NewBuffer(rejectBody))
	reqReject.Header.Set("Content-Type", "application/json")
	reqReject.Header.Set("Authorization", "Bearer "+token)

	respReject, _ := client.Do(reqReject)
	respReject.Body.Close()
	if respReject.StatusCode != http.StatusOK {
		t.Errorf("Failed to reject leave, status: %d", respReject.StatusCode)
	}

	// 3. User tries to edit rejected leave - MUST FAIL
	editPayload := map[string]string{"reason": "Changed my mind"}
	editBody, _ := json.Marshal(editPayload)
	reqEdit, _ := http.NewRequest("PATCH", "http://localhost:8080/api/v1/hr/leaves/"+leaveIDStr, bytes.NewBuffer(editBody))
	reqEdit.Header.Set("Content-Type", "application/json")
	reqEdit.Header.Set("Authorization", "Bearer "+token)

	respEdit, _ := client.Do(reqEdit)
	respEdit.Body.Close()
	
	if respEdit.StatusCode != http.StatusBadRequest {
		t.Errorf("Expected 400 Bad Request when editing rejected leave, got %d", respEdit.StatusCode)
	}
}
