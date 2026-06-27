package model

import "time"

// ClientComplaint represents the 'client_complaints' table (formerly 'complaints').
// Now tracks external client complaints tied to leads/orders.
type ClientComplaint struct {
	ID          int        `json:"id" db:"id"`
	CreatedBy   int        `json:"created_by" db:"created_by"`
	AssignedTo  *int       `json:"assigned_to" db:"assigned_to"`
	Title       string     `json:"title" db:"title"`
	Description string     `json:"description" db:"description"`
	Status      string     `json:"status" db:"status"`
	Priority    string     `json:"priority" db:"priority"`
	LeadID      *int       `json:"lead_id" db:"lead_id"`
	OrderID     *int       `json:"order_id" db:"order_id"`
	ClientName  *string    `json:"client_name" db:"client_name"`
	ClientPhone *string    `json:"client_phone" db:"client_phone"`
	EscalatedAt *time.Time `json:"escalated_at" db:"escalated_at"`
	ResolvedAt  *time.Time `json:"resolved_at" db:"resolved_at"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`
}
