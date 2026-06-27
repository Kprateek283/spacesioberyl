package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/crm/dto"
	"github.com/spacesioberyl/system-v1/internal/crm/service"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

type ComplaintHandler struct {
	svc *service.ComplaintService
}

func NewComplaintHandler(svc *service.ComplaintService) *ComplaintHandler {
	return &ComplaintHandler{svc: svc}
}

// Create maps to POST /api/v1/crm/complaints
func (h *ComplaintHandler) Create(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendCRMError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.CreateClientComplaintRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	complaint, err := h.svc.Create(r.Context(), claims.UserID, req)
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(complaint)
}

// List maps to GET /api/v1/crm/complaints
func (h *ComplaintHandler) List(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	assignedTo, _ := strconv.Atoi(r.URL.Query().Get("assigned_to"))
	createdBy, _ := strconv.Atoi(r.URL.Query().Get("created_by"))

	complaints, err := h.svc.List(r.Context(), status, assignedTo, createdBy)
	if err != nil {
		sendCRMError(w, http.StatusInternalServerError, "Failed to fetch complaints")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(complaints)
}

// Assign maps to PATCH /api/v1/crm/complaints/:id/assign
func (h *ComplaintHandler) Assign(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid complaint ID")
		return
	}

	var req dto.AssignComplaintRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.Assign(r.Context(), id, req.AssignedTo); err != nil {
		sendCRMError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"message": "Complaint assigned"})
}

// UpdateStatus maps to PATCH /api/v1/crm/complaints/:id/status
func (h *ComplaintHandler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid complaint ID")
		return
	}

	var req dto.UpdateComplaintStatusRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.UpdateStatus(r.Context(), id, req); err != nil {
		sendCRMError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"message": "Complaint status updated"})
}
