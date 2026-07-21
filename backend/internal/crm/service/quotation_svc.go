package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"html/template"
	"time"

	"github.com/go-pdf/fpdf"
	"github.com/spacesioberyl/system-v1/internal/broker"
	"github.com/spacesioberyl/system-v1/internal/crm/dto"
	"github.com/spacesioberyl/system-v1/internal/crm/model"
	"github.com/spacesioberyl/system-v1/internal/crm/repository"
	"github.com/spacesioberyl/system-v1/internal/middleware"
	"github.com/spacesioberyl/system-v1/internal/storage"
)

type QuotationService struct {
	repo *repository.QuotationRepository
}

func NewQuotationService(repo *repository.QuotationRepository) *QuotationService {
	return &QuotationService{repo: repo}
}

// Create handles line-item math, quotation persistence, and PDF generation/upload.
func (s *QuotationService) Create(ctx context.Context, leadID, userID int, req dto.CreateQuotationRequest) (*model.Quotation, error) {
	if req.PaymentTermType == "cash" && !middleware.GetGhostMode(ctx) {
		return nil, errors.New("cash payment terms require ghost mode to be enabled")
	}

	if len(req.LineItems) == 0 {
		return nil, errors.New("at least one line item is required")
	}

	// 1. Calculate line-item totals
	var subtotal float64
	var items []*model.QuotationLineItem
	for _, li := range req.LineItems {
		if li.Quantity <= 0 || li.UnitPrice <= 0 {
			return nil, errors.New("quantity and unit_price must be greater than zero")
		}
		lineTotal := li.Quantity * li.UnitPrice
		subtotal += lineTotal

		desc := li.Description
		items = append(items, &model.QuotationLineItem{
			ItemName:    li.ItemName,
			Description: &desc,
			Quantity:    li.Quantity,
			UnitPrice:   li.UnitPrice,
			TotalPrice:  lineTotal,
		})
	}

	// 2. Calculate tax (per-quotation rate, entered manually by user)
	taxAmount := subtotal * (req.TaxRate / 100)
	totalAmount := subtotal + taxAmount

	// 3. Marshal payment_term_details
	termDetailsJSON, _ := json.Marshal(req.PaymentTermDetails)

	// 4. Determine if this is a custom PDF upload
	isCustomPdf := req.CustomPdfURL != nil && *req.CustomPdfURL != ""

	quotation := &model.Quotation{
		LeadID:             leadID,
		CreatedBy:          userID,
		Subtotal:           subtotal,
		TaxRate:            req.TaxRate,
		TaxAmount:          taxAmount,
		TotalAmount:        totalAmount,
		PaymentTermType:    req.PaymentTermType,
		PaymentTermDetails: termDetailsJSON,
		Status:             "draft",
		PdfURL:             req.CustomPdfURL,
		IsCustomPdf:        isCustomPdf,
	}

	// 5. Save to database (transactional with line items)
	result, err := s.repo.Create(ctx, quotation, items)
	if err != nil {
		return nil, fmt.Errorf("failed to create quotation: %w", err)
	}

	// 6. If no custom PDF, generate one and upload to MinIO
	if !isCustomPdf {
		pdfURL, err := s.generateAndUploadPDF(ctx, result, items)
		if err != nil {
			// PDF generation failure is non-fatal — quotation is still saved
			fmt.Printf("⚠️ PDF generation failed for quotation %d: %v\n", result.ID, err)
		} else {
			_ = s.repo.UpdatePdfURL(ctx, result.ID, pdfURL)
			result.PdfURL = &pdfURL
		}
	}

	return result, nil
}

func (s *QuotationService) ListByLead(ctx context.Context, leadID int) ([]*model.Quotation, error) {
	return s.repo.ListByLead(ctx, leadID)
}

func (s *QuotationService) UpdateStatus(ctx context.Context, quotationID int, req dto.UpdateQuotationStatusRequest) error {
	valid := map[string]bool{"sent": true, "client_approved": true, "rejected": true}
	if !valid[req.Status] {
		return errors.New("status must be one of: sent, client_approved, rejected")
	}

	if err := s.repo.UpdateStatus(ctx, quotationID, req.Status); err != nil {
		return err
	}

	// Module 3 → 4 Handoff: Publish event so the worker auto-creates an Order
	if req.Status == "client_approved" {
		quotation, err := s.repo.GetByID(ctx, quotationID)
		if err != nil {
			// Status already updated — log but don't fail the request
			fmt.Printf("⚠️ Quotation %d approved but failed to fetch for event: %v\n", quotationID, err)
			return nil
		}

		_ = broker.PublishEvent(ctx, broker.QueueQuoteApproved, map[string]interface{}{
			"quotation_id":     quotation.ID,
			"lead_id":          quotation.LeadID,
			"payment_term_type": quotation.PaymentTermType,
		})
	}

	return nil
}

func (s *QuotationService) GetByID(ctx context.Context, id int) (*model.Quotation, error) {
	return s.repo.GetByID(ctx, id)
}

// generateAndUploadPDF creates a professional PDF quotation and uploads it to MinIO.
// Uses go-pdf/fpdf for pure Go PDF generation (no external dependencies).
func (s *QuotationService) generateAndUploadPDF(ctx context.Context, q *model.Quotation, items []*model.QuotationLineItem) (string, error) {
	pdf := fpdf.New("P", "mm", "A4", "")
	pdf.SetAutoPageBreak(true, 20)
	pdf.AddPage()

	// Header
	pdf.SetFont("Arial", "B", 20)
	pdf.Cell(190, 12, "QUOTATION")
	pdf.Ln(15)

	// Quotation metadata
	pdf.SetFont("Arial", "", 10)
	pdf.Cell(95, 6, fmt.Sprintf("Quotation #: QT-%06d", q.ID))
	pdf.Cell(95, 6, fmt.Sprintf("Date: %s", q.CreatedAt.Format("02 Jan 2006")))
	pdf.Ln(8)
	pdf.Cell(95, 6, fmt.Sprintf("Payment Terms: %s", template.HTMLEscapeString(q.PaymentTermType)))
	pdf.Ln(12)

	// Table header
	pdf.SetFont("Arial", "B", 10)
	pdf.SetFillColor(230, 230, 230)
	pdf.CellFormat(10, 8, "#", "1", 0, "C", true, 0, "")
	pdf.CellFormat(70, 8, "Item", "1", 0, "L", true, 0, "")
	pdf.CellFormat(25, 8, "Qty", "1", 0, "C", true, 0, "")
	pdf.CellFormat(35, 8, "Unit Price", "1", 0, "R", true, 0, "")
	pdf.CellFormat(40, 8, "Total", "1", 0, "R", true, 0, "")
	pdf.Ln(-1)

	// Table rows
	pdf.SetFont("Arial", "", 10)
	for i, item := range items {
		pdf.CellFormat(10, 7, fmt.Sprintf("%d", i+1), "1", 0, "C", false, 0, "")
		pdf.CellFormat(70, 7, item.ItemName, "1", 0, "L", false, 0, "")
		pdf.CellFormat(25, 7, fmt.Sprintf("%.2f", item.Quantity), "1", 0, "C", false, 0, "")
		pdf.CellFormat(35, 7, fmt.Sprintf("%.2f", item.UnitPrice), "1", 0, "R", false, 0, "")
		pdf.CellFormat(40, 7, fmt.Sprintf("%.2f", item.TotalPrice), "1", 0, "R", false, 0, "")
		pdf.Ln(-1)
	}

	// Totals
	pdf.Ln(5)
	pdf.SetFont("Arial", "", 11)
	pdf.Cell(105, 7, "")
	pdf.Cell(40, 7, "Subtotal:")
	pdf.CellFormat(40, 7, fmt.Sprintf("%.2f", q.Subtotal), "", 0, "R", false, 0, "")
	pdf.Ln(7)

	pdf.Cell(105, 7, "")
	pdf.Cell(40, 7, fmt.Sprintf("Tax (%.1f%%):", q.TaxRate))
	pdf.CellFormat(40, 7, fmt.Sprintf("%.2f", q.TaxAmount), "", 0, "R", false, 0, "")
	pdf.Ln(7)

	pdf.SetFont("Arial", "B", 12)
	pdf.Cell(105, 8, "")
	pdf.Cell(40, 8, "Total:")
	pdf.CellFormat(40, 8, fmt.Sprintf("%.2f", q.TotalAmount), "", 0, "R", false, 0, "")

	// Write PDF to buffer
	var buf bytes.Buffer
	if err := pdf.Output(&buf); err != nil {
		return "", fmt.Errorf("failed to generate PDF: %w", err)
	}

	// Upload to the private bucket. UploadFile returns the object key; the stored
	// value routes through the authenticated /api/v1/files endpoint rather than a
	// public URL (backend-bugs #12).
	objectName := fmt.Sprintf("quotations/%d/QT-%06d_%s.pdf", q.LeadID, q.ID, time.Now().Format("20060102"))
	key, err := storage.UploadFile(ctx, objectName, &buf, int64(buf.Len()), "application/pdf")
	if err != nil {
		return "", err
	}

	return "/api/v1/files/" + key, nil
}
