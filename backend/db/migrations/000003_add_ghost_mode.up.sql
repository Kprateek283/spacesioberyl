-- Ghost Mode: Add PIN columns to users table for dual-PIN authentication
-- Only the Super Admin will use these; NULL means PINs not yet set up.

ALTER TABLE users ADD COLUMN pin_hash VARCHAR(255) NULL;
ALTER TABLE users ADD COLUMN high_security_pin_hash VARCHAR(255) NULL;
