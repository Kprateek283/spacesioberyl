package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/hr/dto"
	"github.com/spacesioberyl/system-v1/internal/hr/service"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

type AttendanceHandler struct {
	svc *service.AttendanceService
}

func NewAttendanceHandler(svc *service.AttendanceService) *AttendanceHandler {
	return &AttendanceHandler{svc: svc}
}

func sendHRError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(dto.BasicResponse{Error: msg})
}

// CheckIn maps to POST /api/v1/hr/attendance/check-in
func (h *AttendanceHandler) CheckIn(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendHRError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.CheckInRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		// Allow empty body (no override)
		req = dto.CheckInRequest{}
	}

	// Extract client IP from request (handles X-Forwarded-For)
	clientIP := extractClientIP(r)

	att, err := h.svc.CheckIn(r.Context(), claims.UserID, clientIP, req)
	if err != nil {
		sendHRError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(att)
}

// CheckOut maps to POST /api/v1/hr/attendance/check-out
func (h *AttendanceHandler) CheckOut(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendHRError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	att, err := h.svc.CheckOut(r.Context(), claims.UserID)
	if err != nil {
		sendHRError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(att)
}

// GetMyAttendance maps to GET /api/v1/hr/attendance/me
func (h *AttendanceHandler) GetMyAttendance(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendHRError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	startDate := r.URL.Query().Get("start_date")
	endDate := r.URL.Query().Get("end_date")

	records, err := h.svc.GetMyAttendance(r.Context(), claims.UserID, startDate, endDate)
	if err != nil {
		sendHRError(w, http.StatusInternalServerError, "Failed to fetch attendance")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(records)
}

// ListAll maps to GET /api/v1/hr/attendance (Admin only)
func (h *AttendanceHandler) ListAll(w http.ResponseWriter, r *http.Request) {
	date := r.URL.Query().Get("date")

	records, err := h.svc.ListAll(r.Context(), date)
	if err != nil {
		sendHRError(w, http.StatusInternalServerError, "Failed to fetch attendance")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(records)
}

// ListOverrides maps to GET /api/v1/hr/attendance/overrides (Admin only)
func (h *AttendanceHandler) ListOverrides(w http.ResponseWriter, r *http.Request) {
	records, err := h.svc.ListPendingOverrides(r.Context())
	if err != nil {
		sendHRError(w, http.StatusInternalServerError, "Failed to fetch overrides")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(records)
}

// ResolveOverride maps to PATCH /api/v1/hr/attendance/overrides/:id (Admin only)
func (h *AttendanceHandler) ResolveOverride(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendHRError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	idStr := chi.URLParam(r, "id")
	attendanceID, err := strconv.Atoi(idStr)
	if err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid attendance ID")
		return
	}

	var req dto.ResolveOverrideRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.ResolveOverride(r.Context(), attendanceID, claims.UserID, req); err != nil {
		sendHRError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Override resolved"})
}

// extractClientIP pulls the real client IP, handling proxies
func extractClientIP(r *http.Request) string {
	// Check X-Forwarded-For first (may be set by reverse proxy)
	xff := r.Header.Get("X-Forwarded-For")
	if xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}

	// Check X-Real-Ip
	xri := r.Header.Get("X-Real-Ip")
	if xri != "" {
		return xri
	}

	// Fallback to RemoteAddr (strip port)
	ip := r.RemoteAddr
	if idx := strings.LastIndex(ip, ":"); idx != -1 {
		ip = ip[:idx]
	}
	return ip
}
