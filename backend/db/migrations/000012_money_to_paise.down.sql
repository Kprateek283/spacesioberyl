-- Reverse #15: BIGINT paise back to DECIMAL rupees (col / 100.0).

ALTER TABLE office_expenses
    ALTER COLUMN amount TYPE DECIMAL(10, 2) USING (amount / 100.0);

ALTER TABLE quotations
    ALTER COLUMN subtotal     TYPE DECIMAL(12, 2) USING (subtotal / 100.0),
    ALTER COLUMN tax_amount   TYPE DECIMAL(12, 2) USING (tax_amount / 100.0),
    ALTER COLUMN total_amount TYPE DECIMAL(12, 2) USING (total_amount / 100.0);

ALTER TABLE quotation_line_items
    ALTER COLUMN unit_price  TYPE DECIMAL(12, 2) USING (unit_price / 100.0),
    ALTER COLUMN total_price TYPE DECIMAL(12, 2) USING (total_price / 100.0);

ALTER TABLE purchase_orders
    ALTER COLUMN total_amount TYPE DECIMAL(12, 2) USING (total_amount / 100.0);

ALTER TABLE installers
    ALTER COLUMN standard_rate TYPE DECIMAL(10, 2) USING (standard_rate / 100.0);

ALTER TABLE installations ALTER COLUMN installer_advance_amount DROP DEFAULT;
ALTER TABLE installations ALTER COLUMN installer_final_amount   DROP DEFAULT;
ALTER TABLE installations
    ALTER COLUMN agreed_installer_price   TYPE DECIMAL(10, 2) USING (agreed_installer_price / 100.0),
    ALTER COLUMN installer_advance_amount TYPE DECIMAL(10, 2) USING (installer_advance_amount / 100.0),
    ALTER COLUMN installer_final_amount   TYPE DECIMAL(10, 2) USING (installer_final_amount / 100.0);
ALTER TABLE installations ALTER COLUMN installer_advance_amount SET DEFAULT 0.00;
ALTER TABLE installations ALTER COLUMN installer_final_amount   SET DEFAULT 0.00;

ALTER TABLE installer_payments
    ALTER COLUMN amount TYPE DECIMAL(10, 2) USING (amount / 100.0);
