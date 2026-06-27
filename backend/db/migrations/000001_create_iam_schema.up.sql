-- 1. Create ENUMs for strict constraint checking
CREATE TYPE user_role AS ENUM ('super_admin', 'admin', 'staff');
CREATE TYPE user_department AS ENUM ('operations', 'technical', 'accounts', 'sales', 'management');

-- 2. Create the Roles Table (Allows for future dynamic permissions if needed)
CREATE TABLE IF NOT EXISTS roles (
                                     id SERIAL PRIMARY KEY,
                                     name user_role UNIQUE NOT NULL,
                                     description TEXT,
                                     created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create the Users Table
CREATE TABLE IF NOT EXISTS users (
                                     id SERIAL PRIMARY KEY,
                                     name VARCHAR(255) NOT NULL,
                                     email VARCHAR(255) UNIQUE NOT NULL,

    -- Security & Auth
                                     password_hash VARCHAR(255) NOT NULL,

    -- RBAC & Organization
                                     role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
                                     department user_department NOT NULL,

    -- Status
                                     is_active BOOLEAN DEFAULT TRUE,

    -- Timestamps
                                     created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                                     updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Create an Index for faster login lookups
CREATE INDEX idx_users_email ON users(email);