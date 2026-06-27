package model

import (
	"encoding/json"
	"time"
)

// Lead represents the 'leads' table
type Lead struct {
	ID          int       `json:"id" db:"id"`
	ClientName  string    `json:"client_name" db:"client_name"`
	ClientPhone string    `json:"client_phone" db:"client_phone"`
	ClientEmail *string   `json:"client_email" db:"client_email"`
	Source      *string   `json:"source" db:"source"`
	AssignedTo  *int      `json:"assigned_to" db:"assigned_to"`
	Status      string    `json:"status" db:"status"`
	LostReason  *string   `json:"lost_reason,omitempty" db:"lost_reason"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// FollowUp represents the 'follow_ups' table
type FollowUp struct {
	ID           int        `json:"id" db:"id"`
	LeadID       int        `json:"lead_id" db:"lead_id"`
	CreatedBy    int        `json:"created_by" db:"created_by"`
	ScheduledFor time.Time  `json:"scheduled_for" db:"scheduled_for"`
	Notes        *string    `json:"notes" db:"notes"`
	Status       string     `json:"status" db:"status"`
	CompletedAt  *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	OutcomeNotes *string    `json:"outcome_notes,omitempty" db:"outcome_notes"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
}

// Quotation represents the 'quotations' table
type Quotation struct {
	ID                 int             `json:"id" db:"id"`
	LeadID             int             `json:"lead_id" db:"lead_id"`
	CreatedBy          int             `json:"created_by" db:"created_by"`
	Subtotal           float64         `json:"subtotal" db:"subtotal"`
	TaxRate            float64         `json:"tax_rate" db:"tax_rate"`
	TaxAmount          float64         `json:"tax_amount" db:"tax_amount"`
	TotalAmount        float64         `json:"total_amount" db:"total_amount"`
	PaymentTermType    string          `json:"payment_term_type" db:"payment_term_type"`
	PaymentTermDetails json.RawMessage `json:"payment_term_details" db:"payment_term_details"`
	Status             string          `json:"status" db:"status"`
	PdfURL             *string         `json:"pdf_url" db:"pdf_url"`
	IsCustomPdf        bool            `json:"is_custom_pdf" db:"is_custom_pdf"`
	CreatedAt          time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time       `json:"updated_at" db:"updated_at"`
}

// QuotationLineItem represents the 'quotation_line_items' table
type QuotationLineItem struct {
	ID          int     `json:"id" db:"id"`
	QuotationID int     `json:"quotation_id" db:"quotation_id"`
	ItemName    string  `json:"item_name" db:"item_name"`
	Description *string `json:"description" db:"description"`
	Quantity    float64 `json:"quantity" db:"quantity"`
	UnitPrice   float64 `json:"unit_price" db:"unit_price"`
	TotalPrice  float64 `json:"total_price" db:"total_price"`
}
