-- Feature: External Contractor & Site Management (Manual Verification Model)
-- Adds installer lifecycle tracking, daily verification logs, and payment tracking.

-- 1. UPDATE EXISTING TABLE: installations
ALTER TABLE installations
ADD COLUMN installer_job_status VARCHAR(50) NOT NULL DEFAULT 'assigned',
ADD COLUMN installer_advance_amount DECIMAL(10, 2) DEFAULT 0.00,
ADD COLUMN installer_final_amount DECIMAL(10, 2) DEFAULT 0.00;

-- 2. NEW TABLE: Daily Attendance & Verification Logs
CREATE TABLE installer_daily_logs (
    id SERIAL PRIMARY KEY,
    installation_id INT NOT NULL REFERENCES installations(id) ON DELETE CASCADE,
    installer_id INT NOT NULL REFERENCES installers(id),

    date DATE NOT NULL DEFAULT CURRENT_DATE,

    -- Accountability: Who verified they were there?
    verified_by INT NOT NULL REFERENCES users(id),

    check_in_time TIMESTAMP WITH TIME ZONE,
    verification_notes TEXT,
    proof_photo_url TEXT,

    check_out_time TIMESTAMP WITH TIME ZONE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(installation_id, installer_id, date)
);

-- 3. NEW TABLE: Installer Payments (Tracking money going OUT to the contractor)
CREATE TABLE installer_payments (
    id SERIAL PRIMARY KEY,
    installation_id INT NOT NULL REFERENCES installations(id),
    installer_id INT NOT NULL REFERENCES installers(id),
    processed_by INT NOT NULL REFERENCES users(id),

    amount DECIMAL(10, 2) NOT NULL,
    payment_type VARCHAR(50) NOT NULL,
    payment_mode VARCHAR(50) NOT NULL,
    transaction_reference VARCHAR(255),

    paid_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
