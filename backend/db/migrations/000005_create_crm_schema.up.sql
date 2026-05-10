-- Module 3: CRM & Sales Pipeline
-- Creates tables for Leads, Follow-ups, Quotations, and Quotation Line Items

-- LEADS / ENQUIRIES
CREATE TABLE leads (
    id SERIAL PRIMARY KEY,
    client_name VARCHAR(255) NOT NULL,
    client_phone VARCHAR(50) NOT NULL,
    client_email VARCHAR(255),
    source VARCHAR(100),
    assigned_to INT REFERENCES users(id),
    status VARCHAR(50) NOT NULL DEFAULT 'new',
    lost_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- FOLLOW-UP SCHEDULER
CREATE TABLE follow_ups (
    id SERIAL PRIMARY KEY,
    lead_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    created_by INT NOT NULL REFERENCES users(id),
    scheduled_for TIMESTAMP WITH TIME ZONE NOT NULL,
    notes TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    completed_at TIMESTAMP WITH TIME ZONE,
    outcome_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- QUOTATIONS (Master Record)
CREATE TABLE quotations (
    id SERIAL PRIMARY KEY,
    lead_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    created_by INT NOT NULL REFERENCES users(id),
    subtotal DECIMAL(12, 2) NOT NULL,
    tax_rate DECIMAL(5, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(12, 2) NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    payment_term_type VARCHAR(50) NOT NULL,
    payment_term_details JSONB,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    pdf_url TEXT,
    is_custom_pdf BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- QUOTATION LINE ITEMS (Child Record)
CREATE TABLE quotation_line_items (
    id SERIAL PRIMARY KEY,
    quotation_id INT NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
    item_name VARCHAR(255) NOT NULL,
    description TEXT,
    quantity DECIMAL(10, 2) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    total_price DECIMAL(12, 2) NOT NULL
);
