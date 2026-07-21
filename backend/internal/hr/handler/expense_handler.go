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

type ExpenseHandler struct {
	svc *service.ExpenseService
}

func NewExpenseHandler(svc *service.ExpenseService) *ExpenseHandler {
	return &ExpenseHandler{svc: svc}
}

// Create maps to POST /api/v1/hr/expenses
func (h *ExpenseHandler) Create(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendHRError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req dto.CreateExpenseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	expense, err := h.svc.Create(r.Context(), claims.UserID, req)
	if err != nil {
		sendHRError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(expense)
}

// List maps to GET /api/v1/hr/expenses
func (h *ExpenseHandler) List(w http.ResponseWriter, r *http.Request) {
	startDate := r.URL.Query().Get("start_date")
	endDate := r.URL.Query().Get("end_date")
	loggedBy, _ := strconv.Atoi(r.URL.Query().Get("logged_by"))

	limit, offset := middleware.Paginate(r)
	expenses, err := h.svc.List(r.Context(), startDate, endDate, loggedBy, limit, offset)
	if err != nil {
		sendHRError(w, http.StatusInternalServerError, "Failed to fetch expenses")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(expenses)
}

// GetByID maps to GET /api/v1/hr/expenses/:id
func (h *ExpenseHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendHRError(w, http.StatusBadRequest, "Invalid expense ID")
		return
	}

	expense, err := h.svc.GetByID(r.Context(), id)
	if err != nil {
		sendHRError(w, http.StatusNotFound, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(expense)
}
