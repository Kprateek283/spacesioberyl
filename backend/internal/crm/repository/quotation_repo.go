package repository

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/crm/model"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

type QuotationRepository struct {
	db *pgxpool.Pool
}

func NewQuotationRepository(db *pgxpool.Pool) *QuotationRepository {
	return &QuotationRepository{db: db}
}

// Create inserts a quotation and its line items in a single transaction
func (r *QuotationRepository) Create(ctx context.Context, q *model.Quotation, items []*model.QuotationLineItem) (*model.Quotation, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	// Insert the quotation
	termDetailsJSON, _ := json.Marshal(q.PaymentTermDetails)

	query := `
		INSERT INTO quotations (lead_id, created_by, subtotal, tax_rate, tax_amount, total_amount,
		                        payment_term_type, payment_term_details, status, pdf_url, is_custom_pdf)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING id, lead_id, created_by, subtotal, tax_rate, tax_amount, total_amount,
		          payment_term_type, payment_term_details, status, pdf_url, is_custom_pdf, created_at, updated_at
	`
	var result model.Quotation
	err = tx.QueryRow(ctx, query,
		q.LeadID, q.CreatedBy, q.Subtotal, q.TaxRate, q.TaxAmount, q.TotalAmount,
		q.PaymentTermType, termDetailsJSON, q.Status, q.PdfURL, q.IsCustomPdf,
	).Scan(
		&result.ID, &result.LeadID, &result.CreatedBy, &result.Subtotal,
		&result.TaxRate, &result.TaxAmount, &result.TotalAmount,
		&result.PaymentTermType, &result.PaymentTermDetails, &result.Status,
		&result.PdfURL, &result.IsCustomPdf, &result.CreatedAt, &result.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	// Insert line items
	for _, item := range items {
		itemQuery := `
			INSERT INTO quotation_line_items (quotation_id, item_name, description, quantity, unit_price, total_price)
			VALUES ($1, $2, $3, $4, $5, $6)
		`
		_, err = tx.Exec(ctx, itemQuery, result.ID, item.ItemName, item.Description, item.Quantity, item.UnitPrice, item.TotalPrice)
		if err != nil {
			return nil, err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &result, nil
}

// UpdatePdfURL sets the generated PDF URL after the quotation is created
func (r *QuotationRepository) UpdatePdfURL(ctx context.Context, quotationID int, pdfURL string) error {
	query := `UPDATE quotations SET pdf_url = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`
	_, err := r.db.Exec(ctx, query, pdfURL, quotationID)
	return err
}

// ListByLead returns quotations for a specific lead.
// GHOST MODE: If ghost_mode is false, cash payment types are filtered out.
func (r *QuotationRepository) ListByLead(ctx context.Context, leadID int) ([]*model.Quotation, error) {
	ghostMode := middleware.GetGhostMode(ctx)

	query := `
		SELECT id, lead_id, created_by, subtotal, tax_rate, tax_amount, total_amount,
		       payment_term_type, payment_term_details, status, pdf_url, is_custom_pdf, created_at, updated_at
		FROM quotations WHERE lead_id = $1
	`
	if !ghostMode {
		query += " AND payment_term_type != 'cash'"
	}
	query += " ORDER BY created_at DESC"

	return r.scanQuotations(ctx, query, leadID)
}

// GetByID fetches a single quotation (with ghost mode check)
func (r *QuotationRepository) GetByID(ctx context.Context, id int) (*model.Quotation, error) {
	ghostMode := middleware.GetGhostMode(ctx)

	query := `
		SELECT id, lead_id, created_by, subtotal, tax_rate, tax_amount, total_amount,
		       payment_term_type, payment_term_details, status, pdf_url, is_custom_pdf, created_at, updated_at
		FROM quotations WHERE id = $1
	`
	if !ghostMode {
		query += " AND payment_term_type != 'cash'"
	}

	var q model.Quotation
	err := r.db.QueryRow(ctx, query, id).Scan(
		&q.ID, &q.LeadID, &q.CreatedBy, &q.Subtotal,
		&q.TaxRate, &q.TaxAmount, &q.TotalAmount,
		&q.PaymentTermType, &q.PaymentTermDetails, &q.Status,
		&q.PdfURL, &q.IsCustomPdf, &q.CreatedAt, &q.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("quotation not found")
		}
		return nil, err
	}
	return &q, nil
}

// UpdateStatus changes a quotation's status
func (r *QuotationRepository) UpdateStatus(ctx context.Context, id int, status string) error {
	query := `UPDATE quotations SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`
	tag, err := r.db.Exec(ctx, query, status, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("quotation not found")
	}
	return nil
}

// GetLineItems fetches all line items for a quotation
func (r *QuotationRepository) GetLineItems(ctx context.Context, quotationID int) ([]*model.QuotationLineItem, error) {
	query := `
		SELECT id, quotation_id, item_name, description, quantity, unit_price, total_price
		FROM quotation_line_items WHERE quotation_id = $1
		ORDER BY id ASC
	`
	rows, err := r.db.Query(ctx, query, quotationID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*model.QuotationLineItem
	for rows.Next() {
		var item model.QuotationLineItem
		if err := rows.Scan(&item.ID, &item.QuotationID, &item.ItemName, &item.Description, &item.Quantity, &item.UnitPrice, &item.TotalPrice); err != nil {
			return nil, err
		}
		items = append(items, &item)
	}
	return items, rows.Err()
}

func (r *QuotationRepository) scanQuotations(ctx context.Context, query string, args ...interface{}) ([]*model.Quotation, error) {
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var quotations []*model.Quotation
	for rows.Next() {
		var q model.Quotation
		if err := rows.Scan(
			&q.ID, &q.LeadID, &q.CreatedBy, &q.Subtotal,
			&q.TaxRate, &q.TaxAmount, &q.TotalAmount,
			&q.PaymentTermType, &q.PaymentTermDetails, &q.Status,
			&q.PdfURL, &q.IsCustomPdf, &q.CreatedAt, &q.UpdatedAt,
		); err != nil {
			return nil, err
		}
		quotations = append(quotations, &q)
	}
	return quotations, rows.Err()
}
