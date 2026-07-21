package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/go-playground/validator/v10"
	"github.com/spacesioberyl/system-v1/internal/iam/dto"
	"github.com/spacesioberyl/system-v1/internal/iam/service"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

// validate enforces the `validate:` struct tags on incoming DTOs. Until this was
// wired in, those tags were decorative (backend-bugs #9).
var validate = validator.New(validator.WithRequiredStructEnabled())

type IAMHandler struct {
	svc *service.IAMService
}

func NewIAMHandler(svc *service.IAMService) *IAMHandler {
	return &IAMHandler{svc: svc}
}

// Helper function to send JSON errors
func sendError(w http.ResponseWriter, statusCode int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(dto.BasicResponse{Error: message})
}

// Login maps to POST /api/v1/login
func (h *IAMHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req dto.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}
	if err := validate.Struct(&req); err != nil {
		sendError(w, http.StatusBadRequest, "email and password are required")
		return
	}

	res, err := h.svc.Login(r.Context(), req)
	if err != nil {
		sendError(w, http.StatusUnauthorized, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(res)
}

// CreateUser maps to POST /api/v1/users (Protected by Admin/SuperAdmin RBAC)
func (h *IAMHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
	var req dto.CreateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}
	if err := validate.Struct(&req); err != nil {
		sendError(w, http.StatusBadRequest, "name, a valid email, a password of at least 8 characters, role and department are required")
		return
	}

	// Enforce the role hierarchy: an admin must not be able to mint a
	// super_admin and take over the tenant (backend-bugs #10).
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}
	if !middleware.CanAssignRole(claims.Role, req.Role) {
		sendError(w, http.StatusForbidden, "Forbidden: only a super_admin may create a super_admin")
		return
	}

	// First, we need the Service to fetch the Role ID for the requested Role string
	roleID, err := h.svc.GetRoleID(r.Context(), req.Role)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid role specified")
		return
	}

	newID, err := h.svc.CreateUser(r.Context(), req, roleID)
	if err != nil {
		if strings.Contains(err.Error(), "SQLSTATE 23505") || strings.Contains(err.Error(), "unique constraint") {
			sendError(w, http.StatusConflict, "User with this email already exists")
			return
		}
		sendError(w, http.StatusInternalServerError, "Failed to create user")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"id":      newID,
		"message": "User created successfully",
	})
}

// UpdateUserStatus maps to PATCH /api/v1/users/{id}/status
func (h *IAMHandler) UpdateUserStatus(w http.ResponseWriter, r *http.Request) {
	userIDStr := chi.URLParam(r, "id")
	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid user ID")
		return
	}

	var req dto.UpdateStatusRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.IsActive == nil {
		sendError(w, http.StatusBadRequest, "is_active boolean is required")
		return
	}

	err = h.svc.UpdateStatus(r.Context(), userID, *req.IsActive)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "Failed to update status")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "User status updated"})
}

// GetMe maps to GET /api/v1/users/me
func (h *IAMHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	// 1. Extract the claims from the context (injected by RequireAuth middleware)
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	// 2. Fetch the user using the ID from the token
	user, err := h.svc.GetUserByID(r.Context(), claims.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "User not found")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(user)
}

// ListUsers maps to GET /api/v1/users (Admin/SuperAdmin only)
func (h *IAMHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	limit, offset := middleware.Paginate(r)
	users, total, err := h.svc.ListUsers(r.Context(), limit, offset)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "Failed to fetch users")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(middleware.NewPage(users, total, limit, offset))
}

// RefreshToken maps to POST /api/v1/refresh
func (h *IAMHandler) RefreshToken(w http.ResponseWriter, r *http.Request) {
	var req dto.RefreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	res, err := h.svc.RefreshToken(r.Context(), req.RefreshToken)
	if err != nil {
		sendError(w, http.StatusUnauthorized, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(res)
}

// Logout maps to POST /api/v1/logout
func (h *IAMHandler) Logout(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	// Extract the access token from the Authorization header
	authHeader := r.Header.Get("Authorization")
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")

	// Blacklist the access token and revoke every refresh token for this user
	if err := h.svc.Logout(r.Context(), tokenString, claims.UserID); err != nil {
		sendError(w, http.StatusInternalServerError, "Failed to logout completely")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Logged out successfully"})
}

// ChangePassword maps to PATCH /api/v1/users/me/password
func (h *IAMHandler) ChangePassword(w http.ResponseWriter, r *http.Request) {
	// Extract the user ID from the JWT context
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.ChangePasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}
	if err := validate.Struct(&req); err != nil {
		sendError(w, http.StatusBadRequest, "new_password must be at least 8 characters")
		return
	}

	if err := h.svc.ChangePassword(r.Context(), claims.UserID, req.OldPassword, req.NewPassword); err != nil {
		sendError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Password changed successfully"})
}

// ForgotPassword maps to POST /api/v1/password/forgot
func (h *IAMHandler) ForgotPassword(w http.ResponseWriter, r *http.Request) {
	var req dto.ForgotPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}
	if err := validate.Struct(&req); err != nil {
		sendError(w, http.StatusBadRequest, "a valid email is required")
		return
	}

	// We intentionally do not return an error if the email isn't found
	// to prevent malicious actors from enumerating valid emails.
	_ = h.svc.ForgotPassword(r.Context(), req.Email)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dto.BasicResponse{
		Message: "If that email exists, a password reset OTP has been sent.",
	})
}

// ResetPassword maps to POST /api/v1/password/reset
func (h *IAMHandler) ResetPassword(w http.ResponseWriter, r *http.Request) {
	var req dto.ResetPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}
	if err := validate.Struct(&req); err != nil {
		sendError(w, http.StatusBadRequest, "a valid email, the OTP, and a new_password of at least 8 characters are required")
		return
	}

	if err := h.svc.ResetPassword(r.Context(), req.Email, req.OTP, req.NewPassword); err != nil {
		sendError(w, http.StatusUnauthorized, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Password updated successfully"})
}

// ---------------------------------------------------------
// GHOST MODE HANDLERS
// ---------------------------------------------------------

// SetupPins maps to POST /api/v1/iam/setup-pins (Super Admin only)
func (h *IAMHandler) SetupPins(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.SetupPinsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.SetupPins(r.Context(), claims.UserID, req); err != nil {
		sendError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Ghost Mode PINs configured successfully"})
}

// VerifyPin maps to POST /api/v1/iam/verify-pin (Authenticated users with PINs)
func (h *IAMHandler) VerifyPin(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.VerifyPinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	res, err := h.svc.VerifyPin(r.Context(), claims.UserID, req.Pin)
	if err != nil {
		sendError(w, http.StatusUnauthorized, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(res)
}
