package bff

import (
	"time"

	crmModels "github.com/spacesioberyl/system-v1/internal/crm/model"
	execModels "github.com/spacesioberyl/system-v1/internal/execution/model"
	logModels "github.com/spacesioberyl/system-v1/internal/logistics/model"
)

// ProjectCard represents a lightweight summary of a project across all domains
// (CRM, Logistics, Execution) to be displayed on the Pipeline Kanban board.
type ProjectCard struct {
	ID          int       `json:"id"`           // Master Lead ID
	ClientName  string    `json:"client_name"`
	Status      string    `json:"status"`       // The current unified stage
	Value       float64   `json:"value"`        // Aggregated from approved quote (if any)
	LastUpdated time.Time `json:"last_updated"`
}

// PipelineResponse is the unified payload for the Pipeline screen.
type PipelineResponse struct {
	Leads       []ProjectCard `json:"leads"`       // Sourced from CRM (Status: New, First Call, etc.)
	Procurement []ProjectCard `json:"procurement"` // Sourced from Logistics (Awaiting Vendor, PO Issued)
	Execution   []ProjectCard `json:"execution"`   // Sourced from Execution (Assigned, In Progress)
	Completed   []ProjectCard `json:"completed"`   // Signed off
}

// ProjectDocument represents a file uploaded to the project lifecycle
type ProjectDocument struct {
	ID           int       `json:"id" db:"id"`
	ProjectID    int       `json:"project_id" db:"project_id"`
	FileURL      string    `json:"file_url" db:"file_url"`
	DocumentType string    `json:"document_type" db:"document_type"`
	UploadedBy   int       `json:"uploaded_by" db:"uploaded_by"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// ProjectDetailsResponse is the massive 360-degree payload for the project drawer
type ProjectDetailsResponse struct {
	Lead        *crmModels.Lead                 `json:"lead"`
	Quotes      []crmModels.Quotation           `json:"quotes"`
	Order       *logModels.Order                `json:"order"`
	POs         []logModels.PurchaseOrder       `json:"pos"`
	Job         *execModels.Installation        `json:"job"`
	SiteUpdates []execModels.InstallationUpdate `json:"site_updates"`
	Documents   []ProjectDocument               `json:"documents"`
}

// ActionItem represents a task requiring admin/manager attention
type ActionItem struct {
	ID          string    `json:"id"`
	Type        string    `json:"type"`         // "QUOTE_APPROVAL", "LEAD_ASSIGNMENT"
	Title       string    `json:"title"`
	RequestedBy string    `json:"requested_by"` // User ID or Name
	Amount      float64   `json:"amount"`       // For expenses/quotes. 0 for leaves.
	CreatedAt   time.Time `json:"created_at"`
}

type ActionItemsResponse struct {
	Items []ActionItem `json:"items"`
}

// TimelineEvent represents a chronological action performed by a user
type TimelineEvent struct {
	ID          string    `json:"id"`
	EventType   string    `json:"event_type"` // "QUOTE_CREATED", "LEAD_ASSIGNED"
	Description string    `json:"description"`
	Timestamp   time.Time `json:"timestamp"`
}

type PersonalTimelineResponse struct {
	Events []TimelineEvent `json:"events"`
}
