package crm

import (
	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/crm/handler"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

// RegisterRoutes connects all CRM endpoints under /api/v1/crm
func RegisterRoutes(r chi.Router, leadH *handler.LeadHandler, followUpH *handler.FollowUpHandler, quotationH *handler.QuotationHandler, complaintH *handler.ComplaintHandler) {
	r.Route("/api/v1/crm", func(r chi.Router) {
		// ALL CRM routes require authentication
		r.Use(middleware.RequireAuth)

		// =====================================================
		// A. Leads Pipeline
		// =====================================================
		r.Route("/leads", func(r chi.Router) {
			r.Post("/", leadH.Create)
			r.Get("/", leadH.List)
			r.Get("/{id}", leadH.GetByID)
			r.Patch("/{id}/status", leadH.UpdateStatus)
			r.Patch("/{id}/assign", leadH.Assign)

			// Nested quotation routes under leads
			r.Post("/{id}/quotations", quotationH.Create)
			r.Get("/{id}/quotations", quotationH.ListByLead)
		})

		// =====================================================
		// B. Follow-Up Engine
		// =====================================================
		r.Route("/followups", func(r chi.Router) {
			r.Post("/", followUpH.Create)
			r.Get("/my-queue", followUpH.GetMyQueue)
			r.Patch("/{id}/complete", followUpH.Complete)
		})

		// =====================================================
		// C. Quotation Status (top-level for direct access)
		// =====================================================
		r.Patch("/quotations/{id}/status", quotationH.UpdateStatus)

		// =====================================================
		// D. Client Complaints (Support Tickets)
		// =====================================================
		r.Route("/complaints", func(r chi.Router) {
			// Any authenticated user can create/view
			r.Post("/", complaintH.Create)
			r.Get("/", complaintH.List)

			// Admin / Super Admin only
			r.Group(func(r chi.Router) {
				r.Use(middleware.RequireRole("admin", "super_admin"))
				r.Patch("/{id}/assign", complaintH.Assign)
			})

			// Admin, Super Admin, or Assigned User can update status
			r.Patch("/{id}/status", complaintH.UpdateStatus)
		})
	})
}
