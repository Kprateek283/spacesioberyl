package hr

import (
	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/hr/handler"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

// RegisterRoutes connects all HR endpoints under /api/v1/hr
func RegisterRoutes(r chi.Router, attH *handler.AttendanceHandler, expH *handler.ExpenseHandler, leaveH *handler.LeaveHandler) {
	r.Route("/api/v1/hr", func(r chi.Router) {
		// ALL HR routes require authentication
		r.Use(middleware.RequireAuth)

		// =====================================================
		// A. Attendance
		// =====================================================
		r.Route("/attendance", func(r chi.Router) {
			// Any authenticated user
			r.Post("/check-in", attH.CheckIn)
			r.Post("/check-out", attH.CheckOut)
			r.Get("/me", attH.GetMyAttendance)

			// Admin / Super Admin only
			r.Group(func(r chi.Router) {
				r.Use(middleware.RequireRole("admin", "super_admin"))
				r.Get("/", attH.ListAll)
				r.Get("/overrides", attH.ListOverrides)
				r.Patch("/overrides/{id}", attH.ResolveOverride)
			})
		})

		// =====================================================
		// B. Expenses (Daily Office Ledger)
		// =====================================================
		r.Route("/expenses", func(r chi.Router) {
			// Any authenticated user can log an expense
			r.Post("/", expH.Create)

			// Admin / Super Admin / Accounts can view the ledger
			r.Group(func(r chi.Router) {
				r.Use(middleware.RequireRole("admin", "super_admin"))
				r.Get("/", expH.List)
				r.Get("/{id}", expH.GetByID)
			})
		})

		// =====================================================
		// C. Leave Management
		// =====================================================
		r.Route("/leaves", func(r chi.Router) {
			// Employee routes (any authenticated user)
			r.Post("/", leaveH.Request)
			r.Get("/me", leaveH.MyLeaves)
			r.Patch("/{id}", leaveH.EditLeave)
			r.Patch("/{id}/cancel", leaveH.Cancel)

			// Admin / Super Admin only
			r.Group(func(r chi.Router) {
				r.Use(middleware.RequireRole("admin", "super_admin"))
				r.Get("/", leaveH.ListAll)
				r.Patch("/{id}/admin-edit", leaveH.AdminEdit)
				r.Patch("/{id}/status", leaveH.ProcessLeave)
			})
		})
	})
}
