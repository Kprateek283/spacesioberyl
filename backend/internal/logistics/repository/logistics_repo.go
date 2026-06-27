package repository

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/logistics/model"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

type LogisticsRepository struct {
	db *pgxpool.Pool
}

func NewLogisticsRepository(db *pgxpool.Pool) *LogisticsRepository {
	return &LogisticsRepository{db: db}
}

// =====================================================
// VENDOR OPERATIONS
// =====================================================

func (r *LogisticsRepository) CreateVendor(ctx context.Context, v *model.Vendor) (*model.Vendor, error) {
	query := `
		INSERT INTO vendors (company_name, contact_person, phone, email, tax_id, default_payment_mode, address)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, company_name, contact_person, phone, email, tax_id, default_payment_mode, address, is_active, created_at, updated_at
	`
	var result model.Vendor
	err := r.db.QueryRow(ctx, query, v.CompanyName, v.ContactPerson, v.Phone, v.Email, v.TaxID, v.DefaultPaymentMode, v.Address).Scan(
		&result.ID, &result.CompanyName, &result.ContactPerson, &result.Phone, &result.Email,
		&result.TaxID, &result.DefaultPaymentMode, &result.Address, &result.IsActive, &result.CreatedAt, &result.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

func (r *LogisticsRepository) ListVendors(ctx context.Context) ([]*model.Vendor, error) {
	query := `
		SELECT id, company_name, contact_person, phone, email, tax_id, default_payment_mode, address, is_active, created_at, updated_at
		FROM vendors WHERE is_active = true ORDER BY company_name ASC
	`
	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var vendors []*model.Vendor
	for rows.Next() {
		var v model.Vendor
		if err := rows.Scan(&v.ID, &v.CompanyName, &v.ContactPerson, &v.Phone, &v.Email,
			&v.TaxID, &v.DefaultPaymentMode, &v.Address, &v.IsActive, &v.CreatedAt, &v.UpdatedAt); err != nil {
			return nil, err
		}
		vendors = append(vendors, &v)
	}
	return vendors, rows.Err()
}

func (r *LogisticsRepository) GetVendorByID(ctx context.Context, id int) (*model.Vendor, error) {
	query := `
		SELECT id, company_name, contact_person, phone, email, tax_id, default_payment_mode, address, is_active, created_at, updated_at
		FROM vendors WHERE id = $1
	`
	var v model.Vendor
	err := r.db.QueryRow(ctx, query, id).Scan(&v.ID, &v.CompanyName, &v.ContactPerson, &v.Phone, &v.Email,
		&v.TaxID, &v.DefaultPaymentMode, &v.Address, &v.IsActive, &v.CreatedAt, &v.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("vendor not found")
		}
		return nil, err
	}
	return &v, nil
}

// =====================================================
// ORDER OPERATIONS
// =====================================================

// ListOrders returns active orders. GHOST MODE: filters cash payment types.
func (r *LogisticsRepository) ListOrders(ctx context.Context) ([]*model.Order, error) {
	ghostMode := middleware.GetGhostMode(ctx)

	query := `
		SELECT id, quotation_id, lead_id, operations_manager_id, status, payment_term_type, created_at, updated_at
		FROM orders WHERE 1=1
	`
	if !ghostMode {
		query += " AND (payment_term_type IS NULL OR payment_term_type != 'cash')"
	}
	query += " ORDER BY created_at DESC"

	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var orders []*model.Order
	for rows.Next() {
		var o model.Order
		if err := rows.Scan(&o.ID, &o.QuotationID, &o.LeadID, &o.OperationsManagerID, &o.Status, &o.PaymentTermType, &o.CreatedAt, &o.UpdatedAt); err != nil {
			return nil, err
		}
		orders = append(orders, &o)
	}
	return orders, rows.Err()
}

func (r *LogisticsRepository) AssignOrderManager(ctx context.Context, orderID, managerID int) error {
	query := `UPDATE orders SET operations_manager_id = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`
	tag, err := r.db.Exec(ctx, query, managerID, orderID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("order not found")
	}
	return nil
}

// CreateOrderFromQuotation is called by the background worker when a quote is approved.
func (r *LogisticsRepository) CreateOrderFromQuotation(ctx context.Context, quotationID, leadID int, paymentTermType string) (int, error) {
	query := `
		INSERT INTO orders (quotation_id, lead_id, payment_term_type)
		VALUES ($1, $2, $3)
		RETURNING id
	`
	var id int
	err := r.db.QueryRow(ctx, query, quotationID, leadID, paymentTermType).Scan(&id)
	return id, err
}

// =====================================================
func (r *LogisticsRepository) UpdateOrderStatus(ctx context.Context, orderID int, status string) error {
	query := `UPDATE orders SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`
	_, err := r.db.Exec(ctx, query, status, orderID)
	return err
}

// =====================================================
// PURCHASE ORDER OPERATIONS

func (r *LogisticsRepository) CreatePurchaseOrder(ctx context.Context, po *model.PurchaseOrder) (*model.PurchaseOrder, error) {
	query := `
		INSERT INTO purchase_orders (order_id, vendor_id, created_by, total_amount, expected_delivery_date)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, order_id, vendor_id, created_by, total_amount, status, payment_status, expected_delivery_date, created_at
	`
	var result model.PurchaseOrder
	err := r.db.QueryRow(ctx, query, po.OrderID, po.VendorID, po.CreatedBy, po.TotalAmount, po.ExpectedDeliveryDate).Scan(
		&result.ID, &result.OrderID, &result.VendorID, &result.CreatedBy,
		&result.TotalAmount, &result.Status, &result.PaymentStatus, &result.ExpectedDeliveryDate, &result.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

// =====================================================
// DISPATCH OPERATIONS
// =====================================================

func (r *LogisticsRepository) CreateDispatch(ctx context.Context, d *model.Dispatch) (*model.Dispatch, error) {
	query := `
		INSERT INTO dispatches (order_id, operations_staff_id, loading_responsibility, transport_driver_name, transport_vehicle_no, transport_phone)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, order_id, operations_staff_id, loading_responsibility, transport_driver_name, transport_vehicle_no, transport_phone,
		          dispatch_time, delivery_time, status, delivery_challan_url, notes, created_at
	`
	var result model.Dispatch
	err := r.db.QueryRow(ctx, query, d.OrderID, d.OperationsStaffID, d.LoadingResponsibility,
		d.TransportDriverName, d.TransportVehicleNo, d.TransportPhone).Scan(
		&result.ID, &result.OrderID, &result.OperationsStaffID, &result.LoadingResponsibility,
		&result.TransportDriverName, &result.TransportVehicleNo, &result.TransportPhone,
		&result.DispatchTime, &result.DeliveryTime, &result.Status, &result.DeliveryChallanURL, &result.Notes, &result.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

func (r *LogisticsRepository) GetMyDispatches(ctx context.Context, staffID int) ([]*model.Dispatch, error) {
	query := `
		SELECT id, order_id, operations_staff_id, loading_responsibility, transport_driver_name, transport_vehicle_no, transport_phone,
		       dispatch_time, delivery_time, status, delivery_challan_url, notes, created_at
		FROM dispatches WHERE operations_staff_id = $1 ORDER BY created_at DESC
	`
	rows, err := r.db.Query(ctx, query, staffID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var dispatches []*model.Dispatch
	for rows.Next() {
		var d model.Dispatch
		if err := rows.Scan(&d.ID, &d.OrderID, &d.OperationsStaffID, &d.LoadingResponsibility,
			&d.TransportDriverName, &d.TransportVehicleNo, &d.TransportPhone,
			&d.DispatchTime, &d.DeliveryTime, &d.Status, &d.DeliveryChallanURL, &d.Notes, &d.CreatedAt); err != nil {
			return nil, err
		}
		dispatches = append(dispatches, &d)
	}
	return dispatches, rows.Err()
}

func (r *LogisticsRepository) LogDispatchTimestamp(ctx context.Context, dispatchID int, timestampType string, challanURL, notes *string) error {
	now := time.Now()
	var query string
	var newStatus string

	switch timestampType {
	case "dispatch":
		query = `UPDATE dispatches SET dispatch_time = $1, status = $2, notes = $3 WHERE id = $4`
		newStatus = "in_transit"
	case "delivery":
		query = `UPDATE dispatches SET delivery_time = $1, status = $2, delivery_challan_url = $3, notes = $4 WHERE id = $5`
		newStatus = "delivered"
	default:
		return errors.New("type must be 'dispatch' or 'delivery'")
	}

	if timestampType == "delivery" {
		tag, err := r.db.Exec(ctx, query, now, newStatus, challanURL, notes, dispatchID)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return errors.New("dispatch not found")
		}
	} else {
		tag, err := r.db.Exec(ctx, query, now, newStatus, notes, dispatchID)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return errors.New("dispatch not found")
		}
	}

	return nil
}

// GetClientInfoByDispatchID joins dispatches → orders → leads to look up the client's phone and name.
// Used for WhatsApp notifications on dispatch/delivery events.
func (r *LogisticsRepository) GetClientInfoByDispatchID(ctx context.Context, dispatchID int) (phone, clientName string, err error) {
	query := `
		SELECT l.client_phone, l.client_name
		FROM dispatches d
		JOIN orders o ON d.order_id = o.id
		JOIN leads l ON o.lead_id = l.id
		WHERE d.id = $1
	`
	err = r.db.QueryRow(ctx, query, dispatchID).Scan(&phone, &clientName)
	return
}

