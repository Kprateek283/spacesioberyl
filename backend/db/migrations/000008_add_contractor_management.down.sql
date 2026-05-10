-- Rollback: External Contractor & Site Management

DROP TABLE IF EXISTS installer_payments;
DROP TABLE IF EXISTS installer_daily_logs;

ALTER TABLE installations
DROP COLUMN IF EXISTS installer_job_status,
DROP COLUMN IF EXISTS installer_advance_amount,
DROP COLUMN IF EXISTS installer_final_amount;
