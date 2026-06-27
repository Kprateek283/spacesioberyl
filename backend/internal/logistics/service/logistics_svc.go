package service

import (
	"context"

	"github.com/spacesioberyl/system-v1/internal/broker"
	"github.com/spacesioberyl/system-v1/internal/logger"
	"github.com/spacesioberyl/system-v1/internal/logistics/model"
	"github.com/spacesioberyl/system-v1/internal/logistics/repository"
)

type LogisticsService interface {
	CreateVendor(ctx context.Context, vendor *model.Vendor) (*model.Vendor, error)
	ListVendors(ctx context.Context) ([]*model.Vendor, error)
	GetVendorByID(ctx context.Context, id int) (*model.Vendor, error)

	ListOrders(ctx context.Context) ([]*model.Order, error)
	AssignOrderManager(ctx context.Context, id int, managerID int) error

	CreatePurchaseOrder(ctx context.Context, po *model.PurchaseOrder) (*model.PurchaseOrder, error)

	CreateDispatch(ctx context.Context, dispatch *model.Dispatch) (*model.Dispatch, error)
	GetMyDispatches(ctx context.Context, userID int) ([]*model.Dispatch, error)
	LogDispatchTimestamp(ctx context.Context, id int, typeStr string, challanURL *string, notes *string) error
}

type logisticsService struct {
	repo *repository.LogisticsRepository
}

func NewLogisticsService(repo *repository.LogisticsRepository) LogisticsService {
	return &logisticsService{repo: repo}
}

func (s *logisticsService) CreateVendor(ctx context.Context, vendor *model.Vendor) (*model.Vendor, error) {
	return s.repo.CreateVendor(ctx, vendor)
}

func (s *logisticsService) ListVendors(ctx context.Context) ([]*model.Vendor, error) {
	return s.repo.ListVendors(ctx)
}

func (s *logisticsService) GetVendorByID(ctx context.Context, id int) (*model.Vendor, error) {
	return s.repo.GetVendorByID(ctx, id)
}

func (s *logisticsService) ListOrders(ctx context.Context) ([]*model.Order, error) {
	return s.repo.ListOrders(ctx)
}

func (s *logisticsService) AssignOrderManager(ctx context.Context, id int, managerID int) error {
	return s.repo.AssignOrderManager(ctx, id, managerID)
}

func (s *logisticsService) CreatePurchaseOrder(ctx context.Context, po *model.PurchaseOrder) (*model.PurchaseOrder, error) {
	result, err := s.repo.CreatePurchaseOrder(ctx, po)
	if err != nil {
		return nil, err
	}

	// Transition the parent order status
	if err := s.repo.UpdateOrderStatus(ctx, po.OrderID, "partially_ordered"); err != nil {
		logger.Log.Error("Failed to update parent order status after PO creation", "order_id", po.OrderID, "error", err)
	}

	return result, nil
}

func (s *logisticsService) CreateDispatch(ctx context.Context, dispatch *model.Dispatch) (*model.Dispatch, error) {
	return s.repo.CreateDispatch(ctx, dispatch)
}

func (s *logisticsService) GetMyDispatches(ctx context.Context, userID int) ([]*model.Dispatch, error) {
	return s.repo.GetMyDispatches(ctx, userID)
}

func (s *logisticsService) LogDispatchTimestamp(ctx context.Context, id int, typeStr string, challanURL *string, notes *string) error {
	if err := s.repo.LogDispatchTimestamp(ctx, id, typeStr, challanURL, notes); err != nil {
		return err
	}

	// Best-effort WhatsApp notification (Synchronous to preserve context tracing/values)
	phone, clientName, err := s.repo.GetClientInfoByDispatchID(ctx, id)
	if err != nil {
		logger.Log.Warn("WhatsApp: failed to look up client info for dispatch", "dispatch_id", id, "error", err)
		return nil
	}

	var status, details string
	switch typeStr {
	case "dispatch":
		status = "Order Dispatched"
		details = "Your materials have been dispatched and are on the way."
	case "delivery":
		status = "Order Delivered"
		details = "Your materials have been delivered successfully."
	}

	vars := map[string]string{
		"1": clientName,
		"2": status,
		"3": details,
	}
	if err := broker.PublishWhatsAppNotification(ctx, phone, "status_update", vars); err != nil {
		logger.Log.Error("WhatsApp: failed to publish notification", "dispatch_id", id, "error", err)
	}

	return nil
}
