package tests

import (
	"bytes"
	"encoding/json"
	"net/http"
	"testing"
)

// TestQuotationMoneyIsIntegerPaise covers #15: money is int64 paise end to end.
// It creates a quotation with a known unit price in paise and asserts the
// server computes line total, tax and grand total with integer math — no
// float drift. This fails before the float64→paise migration (the old code
// returned rupee floats like 3001.0 and rounded tax differently).
//
// qty 2 × 15005000 paise (₹1,50,050.00) = 30010000 subtotal
// tax 18%                                 =  5401800
// total                                   = 35411800
func TestQuotationMoneyIsIntegerPaise(t *testing.T) {
	token := getBaseToken(t)

	body, _ := json.Marshal(map[string]any{
		"payment_term_type": "bank_transfer", // non-cash: no ghost-mode gate
		"tax_rate":          18,
		"line_items": []map[string]any{
			{"item_name": "Paise check", "quantity": 2, "unit_price": 15005000},
		},
	})
	req, _ := http.NewRequest("POST", "http://localhost:8080/api/v1/crm/leads/1/quotations", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("create quotation: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("create quotation: got %d, want 201", resp.StatusCode)
	}

	// json.Number so a rupee float like 30010000.0 would still decode but fail
	// the integer assertions below.
	var q struct {
		Subtotal    json.Number `json:"subtotal"`
		TaxRate     json.Number `json:"tax_rate"`
		TaxAmount   json.Number `json:"tax_amount"`
		TotalAmount json.Number `json:"total_amount"`
	}
	dec := json.NewDecoder(resp.Body)
	dec.UseNumber()
	if err := dec.Decode(&q); err != nil {
		t.Fatalf("decode quotation: %v", err)
	}

	assertInt := func(field string, got json.Number, want int64) {
		v, err := got.Int64()
		if err != nil {
			t.Errorf("%s = %q is not an integer (money must be paise, not a rupee float): %v", field, got, err)
			return
		}
		if v != want {
			t.Errorf("%s = %d, want %d", field, v, want)
		}
	}
	assertInt("subtotal", q.Subtotal, 30010000)
	assertInt("tax_amount", q.TaxAmount, 5401800)
	assertInt("total_amount", q.TotalAmount, 35411800)

	// tax_rate is a percentage, NOT money — it stays a float and is unchanged.
	if r, _ := q.TaxRate.Float64(); r != 18 {
		t.Errorf("tax_rate = %v, want 18 (percentage, unchanged)", r)
	}
}
