package logistics

import (
	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/logistics/handler"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

// RegisterRoutes connects all Logistics endpoints under /api/v1/logistics
func RegisterRoutes(r chi.Router, h *handler.LogisticsHandler) {
	r.Route("/api/v1/logistics", func(r chi.Router) {
		r.Use(middleware.RequireAuth)

		// A. Vendor Directory
		r.Route("/vendors", func(r chi.Router) {
			r.Get("/", h.ListVendors)
			r.Get("/{id}", h.GetVendor)
			r.Post("/", h.CreateVendor)
		})

		// B. Orders & Procurement
		r.Route("/orders", func(r chi.Router) {
			r.Get("/", h.ListOrders)
			r.Patch("/{id}/assign", h.AssignOrderManager)
			r.Post("/{id}/pos", h.CreatePurchaseOrder)
		})

		// C. Dispatch Tracking
		r.Route("/dispatches", func(r chi.Router) {
			r.Post("/", h.CreateDispatch)
			r.Get("/my-tasks", h.GetMyDispatches)
			r.Patch("/{id}/log", h.LogDispatchTimestamp)
		})
	})
}
