-- Migration 009: Refactor Complaints (HR → CRM) + Add Leave Management
-- Part 1: Convert internal complaints to client-facing support tickets

ALTER TABLE complaints RENAME TO client_complaints;

ALTER TABLE client_complaints
ADD COLUMN lead_id INT REFERENCES leads(id),
ADD COLUMN order_id INT REFERENCES orders(id),
ADD COLUMN client_name VARCHAR(255),
ADD COLUMN client_phone VARCHAR(20);

-- Part 2: HR Leave Management

CREATE TABLE hr_leaves (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    leave_type VARCHAR(50) NOT NULL,       -- 'sick_leave', 'casual_leave', 'unpaid_leave'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,

    status VARCHAR(50) DEFAULT 'pending',  -- 'pending', 'approved', 'rejected', 'cancelled'

    approved_by INT REFERENCES users(id),
    admin_remarks TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
