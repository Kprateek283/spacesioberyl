-- Module 5: Field Execution & Installation
-- Creates tables for Installers, Installations, and Installation Updates

-- INSTALLER DIRECTORY (External Contractors)
CREATE TABLE installers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    expertise_area VARCHAR(255),
    standard_rate DECIMAL(10, 2),
    preferred_payment_mode VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- INSTALLATION JOBS
CREATE TABLE installations (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    technical_manager_id INT NOT NULL REFERENCES users(id),
    installer_id INT REFERENCES installers(id),
    agreed_installer_price DECIMAL(10, 2),
    start_date DATE,
    estimated_completion_date DATE,
    status VARCHAR(50) NOT NULL DEFAULT 'assigned',
    client_signoff_url TEXT,
    client_feedback TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- DAILY SITE UPDATES (Built for Offline Sync)
CREATE TABLE installation_updates (
    id SERIAL PRIMARY KEY,
    installation_id INT NOT NULL REFERENCES installations(id) ON DELETE CASCADE,
    logged_by INT NOT NULL REFERENCES users(id),
    update_time TIMESTAMP WITH TIME ZONE NOT NULL,
    notes TEXT,
    photo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
