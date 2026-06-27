package handler

import (

	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/logistics/dto"
	"github.com/spacesioberyl/system-v1/internal/logistics/model"
	"github.com/spacesioberyl/system-v1/internal/logistics/service"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

type LogisticsHandler struct {
	svc service.LogisticsService
}

func NewLogisticsHandler(svc service.LogisticsService) *LogisticsHandler {
	return &LogisticsHandler{svc: svc}
}

func sendLogError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(dto.BasicResponse{Error: msg})
}

// =====================================================
// VENDOR HANDLERS
// =====================================================

func (h *LogisticsHandler) CreateVendor(w http.ResponseWriter, r *http.Request) {
	var req dto.CreateVendorRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendLogError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	vendor := &model.Vendor{CompanyName: req.CompanyName, Phone: req.Phone}
	if req.ContactPerson != "" {
		vendor.ContactPerson = &req.ContactPerson
	}
	if req.Email != "" {
		vendor.Email = &req.Email
	}
	if req.TaxID != "" {
		vendor.TaxID = &req.TaxID
	}
	if req.DefaultPaymentMode != "" {
		vendor.DefaultPaymentMode = &req.DefaultPaymentMode
	}
	if req.Address != "" {
		vendor.Address = &req.Address
	}

	result, err := h.svc.CreateVendor(r.Context(), vendor)
	if err != nil {
		sendLogError(w, http.StatusInternalServerError, "Failed to create vendor")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(result)
}

func (h *LogisticsHandler) ListVendors(w http.ResponseWriter, r *http.Request) {
	vendors, err := h.svc.ListVendors(r.Context())
	if err != nil {
		sendLogError(w, http.StatusInternalServerError, "Failed to fetch vendors")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(vendors)
}

func (h *LogisticsHandler) GetVendor(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendLogError(w, http.StatusBadRequest, "Invalid vendor ID")
		return
	}
	vendor, err := h.svc.GetVendorByID(r.Context(), id)
	if err != nil {
		sendLogError(w, http.StatusNotFound, err.Error())
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(vendor)
}

// =====================================================
// ORDER HANDLERS
// =====================================================

func (h *LogisticsHandler) ListOrders(w http.ResponseWriter, r *http.Request) {
	orders, err := h.svc.ListOrders(r.Context())
	if err != nil {
		sendLogError(w, http.StatusInternalServerError, "Failed to fetch orders")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(orders)
}

func (h *LogisticsHandler) AssignOrderManager(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendLogError(w, http.StatusBadRequest, "Invalid order ID")
		return
	}
	var req dto.AssignOrderManagerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendLogError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}
	if err := h.svc.AssignOrderManager(r.Context(), id, req.OperationsManagerID); err != nil {
		sendLogError(w, http.StatusBadRequest, err.Error())
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Order manager assigned"})
}

// =====================================================
// PURCHASE ORDER HANDLERS
// =====================================================

func (h *LogisticsHandler) CreatePurchaseOrder(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendLogError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	orderID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendLogError(w, http.StatusBadRequest, "Invalid order ID")
		return
	}
	var req dto.CreatePurchaseOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendLogError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	po := &model.PurchaseOrder{
		OrderID:     orderID,
		VendorID:    req.VendorID,
		CreatedBy:   claims.UserID,
		TotalAmount: req.TotalAmount,
	}
	if req.ExpectedDeliveryDate != "" {
		t, err := time.Parse("2006-01-02", req.ExpectedDeliveryDate)
		if err != nil {
			sendLogError(w, http.StatusBadRequest, "Invalid date format (expected YYYY-MM-DD)")
			return
		}
		po.ExpectedDeliveryDate = &t
	}

	result, err := h.svc.CreatePurchaseOrder(r.Context(), po)
	if err != nil {
		sendLogError(w, http.StatusInternalServerError, "Failed to create purchase order")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(result)
}

// =====================================================
// DISPATCH HANDLERS
// =====================================================

func (h *LogisticsHandler) CreateDispatch(w http.ResponseWriter, r *http.Request) {
	var req dto.CreateDispatchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendLogError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	d := &model.Dispatch{
		OrderID:               req.OrderID,
		OperationsStaffID:     req.OperationsStaffID,
		LoadingResponsibility: req.LoadingResponsibility,
	}
	if req.TransportDriverName != "" {
		d.TransportDriverName = &req.TransportDriverName
	}
	if req.TransportVehicleNo != "" {
		d.TransportVehicleNo = &req.TransportVehicleNo
	}
	if req.TransportPhone != "" {
		d.TransportPhone = &req.TransportPhone
	}

	result, err := h.svc.CreateDispatch(r.Context(), d)
	if err != nil {
		sendLogError(w, http.StatusInternalServerError, "Failed to create dispatch")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(result)
}

func (h *LogisticsHandler) GetMyDispatches(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendLogError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	dispatches, err := h.svc.GetMyDispatches(r.Context(), claims.UserID)
	if err != nil {
		sendLogError(w, http.StatusInternalServerError, "Failed to fetch dispatches")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dispatches)
}

func (h *LogisticsHandler) LogDispatchTimestamp(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendLogError(w, http.StatusBadRequest, "Invalid dispatch ID")
		return
	}
	var req dto.LogDispatchTimestampRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendLogError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	var challanURL, notes *string
	if req.ChallanURL != "" {
		challanURL = &req.ChallanURL
	}
	if req.Notes != "" {
		notes = &req.Notes
	}

	if err := h.svc.LogDispatchTimestamp(r.Context(), id, req.Type, challanURL, notes); err != nil {
		sendLogError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Timestamp logged"})
}
