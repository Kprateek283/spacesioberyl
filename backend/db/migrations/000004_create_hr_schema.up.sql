-- Module 2: Internal HR & Administration
-- Creates tables for Attendance, Complaints, and Office Expenses

-- ATTENDANCE --
CREATE TABLE attendances (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    check_in_time TIMESTAMP WITH TIME ZONE,
    check_out_time TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) NOT NULL DEFAULT 'absent', -- 'present', 'absent', 'half_day', 'off_site', 'pending_override'
    ip_address VARCHAR(50),
    is_office_wifi BOOLEAN DEFAULT false,

    -- Override Request Data
    override_reason TEXT,
    override_status VARCHAR(50), -- 'pending', 'approved', 'rejected'
    override_rejected_reason TEXT,
    reviewed_by INT REFERENCES users(id),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Ensure a user only has one attendance record per day
    UNIQUE(user_id, date)
);

-- COMPLAINTS (Internal Support Tickets) --
CREATE TABLE complaints (
    id SERIAL PRIMARY KEY,
    created_by INT NOT NULL REFERENCES users(id),
    assigned_to INT REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'open', -- 'open', 'in_progress', 'resolved', 'escalated'
    priority VARCHAR(50) NOT NULL DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
    escalated_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- EXPENSES (Daily Office Ledger) --
CREATE TABLE office_expenses (
    id SERIAL PRIMARY KEY,
    logged_by INT NOT NULL REFERENCES users(id),
    amount DECIMAL(10, 2) NOT NULL,
    person_paid VARCHAR(255) NOT NULL,
    context TEXT NOT NULL,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    receipt_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
