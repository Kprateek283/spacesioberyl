package iam

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/httprate"

	// We will implement these packages in the upcoming steps
	"github.com/spacesioberyl/system-v1/internal/iam/handler"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

// RegisterRoutes connects the HTTP paths to the IAM handler functions
func RegisterRoutes(r chi.Router, requireAuth func(http.Handler) http.Handler, h *handler.IAMHandler) {

	// Base API grouping
	r.Route("/api/v1", func(r chi.Router) {

		// ---------------------------------------------------------
		// 1. PUBLIC ROUTES (No Token Required)
		// ---------------------------------------------------------
		r.With(httprate.LimitByIP(5, 1*time.Minute)).Post("/login", h.Login)
		r.Post("/refresh", h.RefreshToken)
		// Password-reset endpoints carry the same per-IP limit as /login so the
		// OTP flow is not brute-forceable (backend-bugs #21).
		r.With(httprate.LimitByIP(5, 1*time.Minute)).Post("/password/forgot", h.ForgotPassword)
		r.With(httprate.LimitByIP(5, 1*time.Minute)).Post("/password/reset", h.ResetPassword)

		// ---------------------------------------------------------
		// 2. PROTECTED ROUTES (Requires valid Access Token)
		// ---------------------------------------------------------
		r.Group(func(r chi.Router) {
			// Middleware: Extracts JWT, validates it, and puts User info in Context
			r.Use(requireAuth)

			// Personal Routes
			r.Post("/logout", h.Logout)
			r.Get("/users/me", h.GetMe)
			r.Patch("/users/me/password", h.ChangePassword)

			// Ghost Mode: PIN-based Authentication
			r.Route("/iam", func(r chi.Router) {
				r.With(httprate.LimitByIP(5, 1*time.Minute)).Post("/verify-pin", h.VerifyPin)

				// Super Admin only: PIN setup
				r.Group(func(r chi.Router) {
					r.Use(middleware.RequireRole("super_admin"))
					r.With(httprate.LimitByIP(5, 1*time.Minute)).Post("/setup-pins", h.SetupPins)
				})
			})

			// -----------------------------------------------------
			// 3. ADMIN / SUPER ADMIN ROUTES (Strict RBAC)
			// -----------------------------------------------------
			r.Group(func(r chi.Router) {
				// Middleware: Checks the Context for allowed roles
				r.Use(middleware.RequireRole("admin", "super_admin"))

				r.Get("/users", h.ListUsers)
				r.Post("/users", h.CreateUser)
				r.Patch("/users/{id}/status", h.UpdateUserStatus)
			})
		})
	})
}
