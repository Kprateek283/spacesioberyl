package execution

import (
	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/execution/handler"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

// RegisterRoutes connects all Execution endpoints under /api/v1/execution
func RegisterRoutes(r chi.Router, h *handler.ExecutionHandler, ch *handler.ContractorHandler) {
	r.Route("/api/v1/execution", func(r chi.Router) {
		r.Use(middleware.RequireAuth)

		// A. Installer Directory
		r.Route("/installers", func(r chi.Router) {
			r.Post("/", h.CreateInstaller)
			r.Get("/", h.ListInstallers)
		})

		// B. Installation Jobs
		r.Route("/jobs", func(r chi.Router) {
			r.Get("/", h.ListJobs)
			r.Get("/my-tasks", h.GetMyJobs)
			r.Patch("/{id}/assign", h.AssignInstaller)
			r.Post("/{id}/updates/sync", h.SyncUpdates)
			r.Get("/{id}/updates", h.GetUpdates)
			r.Patch("/{id}/signoff", h.Signoff)
		})

		// C. Create Installation from Order
		r.Post("/orders/{id}/installation", h.CreateInstallation)

		// D. Contractor Management (Manual Verification Model)
		r.Route("/contractors/jobs", func(r chi.Router) {
			r.Patch("/{id}/status", ch.UpdateInstallerJobStatus)
			r.Post("/{id}/check-in", ch.InstallerCheckIn)
			r.Post("/{id}/check-out", ch.InstallerCheckOut)
			r.Post("/{id}/payments", ch.RecordPayment)
			r.Get("/{id}/ledger", ch.GetLedger)
		})
	})
}

