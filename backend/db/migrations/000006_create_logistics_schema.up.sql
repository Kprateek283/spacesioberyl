-- Module 4: Supply Chain & Logistics
-- Creates tables for Vendors, Orders, Purchase Orders, and Dispatches

-- VENDOR DIRECTORY
CREATE TABLE vendors (
    id SERIAL PRIMARY KEY,
    company_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    phone VARCHAR(50) NOT NULL,
    email VARCHAR(255),
    tax_id VARCHAR(100),
    default_payment_mode VARCHAR(50),
    address TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- PROJECTS / ORDERS (The Handoff Entity)
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    quotation_id INT NOT NULL REFERENCES quotations(id) ON DELETE RESTRICT,
    lead_id INT NOT NULL REFERENCES leads(id),
    operations_manager_id INT REFERENCES users(id),
    status VARCHAR(50) NOT NULL DEFAULT 'procurement',
    payment_term_type VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- PURCHASE ORDERS
CREATE TABLE purchase_orders (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    vendor_id INT NOT NULL REFERENCES vendors(id),
    created_by INT NOT NULL REFERENCES users(id),
    total_amount DECIMAL(12, 2) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    payment_status VARCHAR(50) NOT NULL DEFAULT 'unpaid',
    expected_delivery_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- DISPATCH TRACKING
CREATE TABLE dispatches (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    operations_staff_id INT NOT NULL REFERENCES users(id),
    loading_responsibility VARCHAR(50) NOT NULL,
    transport_driver_name VARCHAR(255),
    transport_vehicle_no VARCHAR(100),
    transport_phone VARCHAR(50),
    dispatch_time TIMESTAMP WITH TIME ZONE,
    delivery_time TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) NOT NULL DEFAULT 'scheduled',
    delivery_challan_url TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
