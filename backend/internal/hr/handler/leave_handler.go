package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/hr/dto"
	"github.com/spacesioberyl/system-v1/internal/hr/service"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

type LeaveHandler struct {
	svc *service.LeaveService
}

func NewLeaveHandler(svc *service.LeaveService) *LeaveHandler {
	return &LeaveHandler{svc: svc}
}

// Request maps to POST /api/v1/hr/leaves
func (h *LeaveHandler) Request(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendHRError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.RequestLeaveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	leave, err := h.svc.Request(r.Context(), claims.UserID, req)
	if err != nil {
		sendHRError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(leave)
}

// MyLeaves maps to GET /api/v1/hr/leaves/me
func (h *LeaveHandler) MyLeaves(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendHRError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	leaves, err := h.svc.MyLeaves(r.Context(), claims.UserID)
	if err != nil {
		sendHRError(w, http.StatusInternalServerError, "Failed to fetch leaves")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(leaves)
}

// EditLeave maps to PATCH /api/v1/hr/leaves/:id
func (h *LeaveHandler) EditLeave(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendHRError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid leave ID")
		return
	}

	var req dto.EditLeaveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.EditLeave(r.Context(), id, claims.UserID, req); err != nil {
		sendHRError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Leave updated"})
}

// Cancel maps to PATCH /api/v1/hr/leaves/:id/cancel
func (h *LeaveHandler) Cancel(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendHRError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid leave ID")
		return
	}

	if err := h.svc.Cancel(r.Context(), id, claims.UserID); err != nil {
		sendHRError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Leave cancelled"})
}

// ListAll maps to GET /api/v1/hr/leaves (admin)
func (h *LeaveHandler) ListAll(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")

	limit, offset := middleware.Paginate(r)
	leaves, total, err := h.svc.ListAll(r.Context(), status, limit, offset)
	if err != nil {
		sendHRError(w, http.StatusInternalServerError, "Failed to fetch leaves")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(middleware.NewPage(leaves, total, limit, offset))
}

// AdminEdit maps to PATCH /api/v1/hr/leaves/:id/admin-edit
func (h *LeaveHandler) AdminEdit(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid leave ID")
		return
	}

	var req dto.AdminEditLeaveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.AdminEdit(r.Context(), id, req); err != nil {
		sendHRError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Leave updated by admin"})
}

// ProcessLeave maps to PATCH /api/v1/hr/leaves/:id/status
func (h *LeaveHandler) ProcessLeave(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendHRError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid leave ID")
		return
	}

	var req dto.ProcessLeaveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.ProcessLeave(r.Context(), id, claims.UserID, req); err != nil {
		sendHRError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Leave " + req.Status})
}
