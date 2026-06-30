package bff

import (
	"context"
	"fmt"
	"io"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/sync/errgroup"

	crmModels "github.com/spacesioberyl/system-v1/internal/crm/model"
	execModels "github.com/spacesioberyl/system-v1/internal/execution/model"
	logModels "github.com/spacesioberyl/system-v1/internal/logistics/model"
	"github.com/spacesioberyl/system-v1/internal/storage"
)

type BFFService struct {
	db *pgxpool.Pool
}

func NewBFFService(db *pgxpool.Pool) *BFFService {
	return &BFFService{db: db}
}

// GetPipeline returns the unified Kanban board state by aggregating CRM, Logistics, and Execution tables.
func (s *BFFService) GetPipeline(ctx context.Context) (*PipelineResponse, error) {
	// A single, highly performant query that joins across the 3 domains
	query := `
		SELECT 
			l.id as project_id, 
			l.client_name,
			l.status as crm_status, 
			COALESCE(o.status, '') as order_status,
			COALESCE(i.status, '') as execution_status,
			COALESCE((SELECT total_amount FROM quotations q WHERE q.lead_id = l.id AND q.status = 'approved' LIMIT 1), 0) as value,
			l.updated_at
		FROM leads l
		LEFT JOIN orders o ON o.lead_id = l.id
		LEFT JOIN installations i ON i.order_id = o.id
		ORDER BY l.updated_at DESC
	`

	rows, err := s.db.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch pipeline: %w", err)
	}
	defer rows.Close()

	resp := &PipelineResponse{
		Leads:       []ProjectCard{},
		Procurement: []ProjectCard{},
		Execution:   []ProjectCard{},
		Completed:   []ProjectCard{},
	}

	for rows.Next() {
		var crmStatus, orderStatus, execStatus string
		card := ProjectCard{}

		err := rows.Scan(
			&card.ID,
			&card.ClientName,
			&crmStatus,
			&orderStatus,
			&execStatus,
			&card.Value,
			&card.LastUpdated,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan pipeline row: %w", err)
		}

		// Bucket routing logic based on the furthest downstream status
		if execStatus == "completed" {
			card.Status = "Completed"
			resp.Completed = append(resp.Completed, card)
		} else if execStatus != "" {
			card.Status = "Execution - " + execStatus
			resp.Execution = append(resp.Execution, card)
		} else if orderStatus != "" {
			card.Status = "Procurement - " + orderStatus
			resp.Procurement = append(resp.Procurement, card)
		} else {
			card.Status = "Lead - " + crmStatus
			resp.Leads = append(resp.Leads, card)
		}
	}

	if err = rows.Err(); err != nil {
		return nil, err
	}

	return resp, nil
}

// GetProjectDetails returns the massive 360-degree view for the Project Drawer
func (s *BFFService) GetProjectDetails(ctx context.Context, projectID int) (*ProjectDetailsResponse, error) {
	resp := &ProjectDetailsResponse{
		Quotes:      []crmModels.Quotation{},
		POs:         []logModels.PurchaseOrder{},
		SiteUpdates: []execModels.InstallationUpdate{},
		Documents:   []ProjectDocument{},
	}

	g, gCtx := errgroup.WithContext(ctx)

	// 1. Fetch Lead (CRM)
	g.Go(func() error {
		var l crmModels.Lead
		query := `SELECT id, client_name, client_phone, client_email, source, assigned_to, status, lost_reason, created_at, updated_at FROM leads WHERE id = $1`
		err := s.db.QueryRow(gCtx, query, projectID).Scan(
			&l.ID, &l.ClientName, &l.ClientPhone, &l.ClientEmail, &l.Source, &l.AssignedTo, &l.Status, &l.LostReason, &l.CreatedAt, &l.UpdatedAt,
		)
		if err == nil {
			resp.Lead = &l
		} else if err != pgx.ErrNoRows {
			return err
		}
		return nil
	})

	// 2. Fetch Quotations (CRM)
	g.Go(func() error {
		query := `SELECT id, lead_id, created_by, subtotal, tax_rate, tax_amount, total_amount, payment_term_type, payment_term_details, status, pdf_url, is_custom_pdf, created_at, updated_at FROM quotations WHERE lead_id = $1`
		rows, err := s.db.Query(gCtx, query, projectID)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var q crmModels.Quotation
			if err := rows.Scan(&q.ID, &q.LeadID, &q.CreatedBy, &q.Subtotal, &q.TaxRate, &q.TaxAmount, &q.TotalAmount, &q.PaymentTermType, &q.PaymentTermDetails, &q.Status, &q.PdfURL, &q.IsCustomPdf, &q.CreatedAt, &q.UpdatedAt); err == nil {
				resp.Quotes = append(resp.Quotes, q)
			}
		}
		return nil
	})

	// 3. Fetch Order (Logistics)
	g.Go(func() error {
		var o logModels.Order
		query := `
			SELECT o.id, o.quotation_id, o.lead_id, o.operations_manager_id, o.status, o.payment_term_type, l.client_name, o.created_at, o.updated_at 
			FROM orders o JOIN leads l ON l.id = o.lead_id WHERE o.lead_id = $1 LIMIT 1`
		err := s.db.QueryRow(gCtx, query, projectID).Scan(
			&o.ID, &o.QuotationID, &o.LeadID, &o.OperationsManagerID, &o.Status, &o.PaymentTermType, &o.ClientName, &o.CreatedAt, &o.UpdatedAt,
		)
		if err == nil {
			resp.Order = &o
			
			// 3.1 Fetch POs inside this goroutine since we need Order ID
			poQuery := `SELECT id, order_id, vendor_id, created_by, total_amount, status, payment_status, expected_delivery_date, created_at FROM purchase_orders WHERE order_id = $1`
			poRows, _ := s.db.Query(gCtx, poQuery, o.ID)
			defer poRows.Close()
			for poRows.Next() {
				var po logModels.PurchaseOrder
				if err := poRows.Scan(&po.ID, &po.OrderID, &po.VendorID, &po.CreatedBy, &po.TotalAmount, &po.Status, &po.PaymentStatus, &po.ExpectedDeliveryDate, &po.CreatedAt); err == nil {
					resp.POs = append(resp.POs, po)
				}
			}

			// 3.2 Fetch Installation inside this goroutine since we need Order ID
			var i execModels.Installation
			instQuery := `SELECT id, order_id, technical_manager_id, installer_id, agreed_installer_price, start_date, estimated_completion_date, status, installer_job_status, installer_advance_amount, installer_final_amount, client_signoff_url, client_feedback, created_at, updated_at FROM installations WHERE order_id = $1 LIMIT 1`
			err = s.db.QueryRow(gCtx, instQuery, o.ID).Scan(
				&i.ID, &i.OrderID, &i.TechnicalManagerID, &i.InstallerID, &i.AgreedInstallerPrice, &i.StartDate, &i.EstimatedCompletionDate, &i.Status, &i.InstallerJobStatus, &i.InstallerAdvanceAmount, &i.InstallerFinalAmount, &i.ClientSignoffURL, &i.ClientFeedback, &i.CreatedAt, &i.UpdatedAt,
			)
			if err == nil {
				resp.Job = &i
				
				// 3.3 Fetch Site Updates
				updQuery := `SELECT id, installation_id, logged_by, update_time, notes, photo_url, created_at FROM installation_updates WHERE installation_id = $1 ORDER BY update_time DESC`
				updRows, _ := s.db.Query(gCtx, updQuery, i.ID)
				defer updRows.Close()
				for updRows.Next() {
					var u execModels.InstallationUpdate
					if err := updRows.Scan(&u.ID, &u.InstallationID, &u.LoggedBy, &u.UpdateTime, &u.Notes, &u.PhotoURL, &u.CreatedAt); err == nil {
						resp.SiteUpdates = append(resp.SiteUpdates, u)
					}
				}
			}
		}
		return nil
	})

	// 4. Fetch Documents
	g.Go(func() error {
		query := `SELECT id, project_id, file_url, document_type, uploaded_by, created_at FROM project_documents WHERE project_id = $1 ORDER BY created_at DESC`
		rows, err := s.db.Query(gCtx, query, projectID)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var d ProjectDocument
			if err := rows.Scan(&d.ID, &d.ProjectID, &d.FileURL, &d.DocumentType, &d.UploadedBy, &d.CreatedAt); err == nil {
				resp.Documents = append(resp.Documents, d)
			}
		}
		return nil
	})

	// Wait for all goroutines to complete
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("failed to fetch project details: %w", err)
	}

	return resp, nil
}

// UploadProjectDocument uploads a file to MinIO and logs it in the CRM database
func (s *BFFService) UploadProjectDocument(ctx context.Context, projectID, uploaderID int, documentType, filename string, file io.Reader, size int64, contentType string) (*ProjectDocument, error) {
	// 1. Upload to MinIO (creates a unique path to prevent overwrites)
	objectName := fmt.Sprintf("projects/%d/docs/%d-%s", projectID, time.Now().Unix(), filename)
	fileURL, err := storage.UploadFile(ctx, objectName, file, size, contentType)
	if err != nil {
		return nil, fmt.Errorf("failed to upload file to storage: %w", err)
	}

	// 2. Insert record into PostgreSQL
	query := `
		INSERT INTO project_documents (project_id, file_url, document_type, uploaded_by)
		VALUES ($1, $2, $3, $4)
		RETURNING id, project_id, file_url, document_type, uploaded_by, created_at
	`
	var doc ProjectDocument
	err = s.db.QueryRow(ctx, query, projectID, fileURL, documentType, uploaderID).Scan(
		&doc.ID, &doc.ProjectID, &doc.FileURL, &doc.DocumentType, &doc.UploadedBy, &doc.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to save document record to db: %w", err)
	}

	return &doc, nil
}

// GetActionItems fetches tasks requiring the user's attention
func (s *BFFService) GetActionItems(ctx context.Context, userID int) (*ActionItemsResponse, error) {
	resp := &ActionItemsResponse{Items: []ActionItem{}}
	
	// Example action items: Leads assigned to this user that are still 'new' or 'first_call'
	query := `SELECT id, client_name, created_at FROM leads WHERE assigned_to = $1 AND status IN ('new', 'first_call') ORDER BY created_at DESC`
	rows, err := s.db.Query(ctx, query, userID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var clientName string
			var createdAt time.Time
			if err := rows.Scan(&id, &clientName, &createdAt); err == nil {
				resp.Items = append(resp.Items, ActionItem{
					ID:          fmt.Sprintf("lead-%d", id),
					Type:        "LEAD_ASSIGNMENT",
					Title:       fmt.Sprintf("New Lead: %s", clientName),
					RequestedBy: "System",
					Amount:      0,
					CreatedAt:   createdAt,
				})
			}
		}
	}
	
	return resp, nil
}

// GetPersonalTimeline fetches chronological events performed by the user
func (s *BFFService) GetPersonalTimeline(ctx context.Context, userID int) (*PersonalTimelineResponse, error) {
	resp := &PersonalTimelineResponse{Events: []TimelineEvent{}}
	
	// Example timeline events: Quotes created by this user
	query := `SELECT id, total_amount, status, created_at FROM quotations WHERE created_by = $1 ORDER BY created_at DESC LIMIT 15`
	rows, err := s.db.Query(ctx, query, userID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var amount float64
			var status string
			var createdAt time.Time
			if err := rows.Scan(&id, &amount, &status, &createdAt); err == nil {
				resp.Events = append(resp.Events, TimelineEvent{
					ID:          fmt.Sprintf("quote-%d", id),
					EventType:   "QUOTE_UPDATE",
					Description: fmt.Sprintf("Quotation #%d (Total: $%.2f) status is %s", id, amount, status),
					Timestamp:   createdAt,
				})
			}
		}
	}
	
	return resp, nil
}

