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

type LeadHandler struct {
	svc *service.LeadService
}

func NewLeadHandler(svc *service.LeadService) *LeadHandler {
	return &LeadHandler{svc: svc}
}

func sendCRMError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(dto.BasicResponse{Error: msg})
}

func (h *LeadHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req dto.CreateLeadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	lead, err := h.svc.Create(r.Context(), req)
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(lead)
}

func (h *LeadHandler) List(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	assignedTo, _ := strconv.Atoi(r.URL.Query().Get("assigned_to"))

	limit, offset := middleware.Paginate(r)
	leads, err := h.svc.List(r.Context(), status, assignedTo, limit, offset)
	if err != nil {
		sendCRMError(w, http.StatusInternalServerError, "Failed to fetch leads")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(leads)
}

func (h *LeadHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid lead ID")
		return
	}

	lead, err := h.svc.GetByID(r.Context(), id)
	if err != nil {
		sendCRMError(w, http.StatusNotFound, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(lead)
}

func (h *LeadHandler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid lead ID")
		return
	}

	var req dto.UpdateLeadStatusRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.UpdateStatus(r.Context(), id, req); err != nil {
		sendCRMError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Lead status updated"})
}

func (h *LeadHandler) Assign(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid lead ID")
		return
	}

	var req dto.AssignLeadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.Assign(r.Context(), id, req.AssignedTo); err != nil {
		sendCRMError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Lead assigned"})
}

// FollowUpHandler

type FollowUpHandler struct {
	svc *service.FollowUpService
}

func NewFollowUpHandler(svc *service.FollowUpService) *FollowUpHandler {
	return &FollowUpHandler{svc: svc}
}

func (h *FollowUpHandler) Create(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendCRMError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.CreateFollowUpRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	followUp, err := h.svc.Create(r.Context(), claims.UserID, req)
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(followUp)
}

func (h *FollowUpHandler) GetMyQueue(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendCRMError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	followUps, err := h.svc.GetMyQueue(r.Context(), claims.UserID)
	if err != nil {
		sendCRMError(w, http.StatusInternalServerError, "Failed to fetch follow-ups")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(followUps)
}

func (h *FollowUpHandler) Complete(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid follow-up ID")
		return
	}

	var req dto.CompleteFollowUpRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.Complete(r.Context(), id, req); err != nil {
		sendCRMError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Follow-up completed"})
}

// QuotationHandler

type QuotationHandler struct {
	svc *service.QuotationService
}

func NewQuotationHandler(svc *service.QuotationService) *QuotationHandler {
	return &QuotationHandler{svc: svc}
}

func (h *QuotationHandler) Create(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendCRMError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	leadID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid lead ID")
		return
	}

	var req dto.CreateQuotationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	quotation, err := h.svc.Create(r.Context(), leadID, claims.UserID, req)
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(quotation)
}

func (h *QuotationHandler) ListByLead(w http.ResponseWriter, r *http.Request) {
	leadID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid lead ID")
		return
	}

	quotations, err := h.svc.ListByLead(r.Context(), leadID)
	if err != nil {
		sendCRMError(w, http.StatusInternalServerError, "Failed to fetch quotations")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(quotations)
}

func (h *QuotationHandler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid quotation ID")
		return
	}

	var req dto.UpdateQuotationStatusRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendCRMError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.UpdateStatus(r.Context(), id, req); err != nil {
		sendCRMError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Quotation status updated"})
}
