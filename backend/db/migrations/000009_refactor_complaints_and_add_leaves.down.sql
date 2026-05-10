-- Rollback: Remove leaves table and revert complaint changes
DROP TABLE IF EXISTS hr_leaves;

ALTER TABLE client_complaints
DROP COLUMN IF EXISTS client_phone,
DROP COLUMN IF EXISTS client_name,
DROP COLUMN IF EXISTS order_id,
DROP COLUMN IF EXISTS lead_id;

ALTER TABLE client_complaints RENAME TO complaints;
