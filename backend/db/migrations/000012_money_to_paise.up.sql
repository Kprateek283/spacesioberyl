-- backend-bugs #15: money moves from DECIMAL rupees to BIGINT paise (integer
-- minor units). Existing values are rupees with 2 decimals; ROUND(col*100)
-- converts to paise losslessly. tax_rate (a percentage) and quantity (a count)
-- are NOT money and stay DECIMAL.

ALTER TABLE office_expenses
    ALTER COLUMN amount TYPE BIGINT USING ROUND(amount * 100);

ALTER TABLE quotations
    ALTER COLUMN subtotal     TYPE BIGINT USING ROUND(subtotal * 100),
    ALTER COLUMN tax_amount   TYPE BIGINT USING ROUND(tax_amount * 100),
    ALTER COLUMN total_amount TYPE BIGINT USING ROUND(total_amount * 100);

ALTER TABLE quotation_line_items
    ALTER COLUMN unit_price  TYPE BIGINT USING ROUND(unit_price * 100),
    ALTER COLUMN total_price TYPE BIGINT USING ROUND(total_price * 100);

ALTER TABLE purchase_orders
    ALTER COLUMN total_amount TYPE BIGINT USING ROUND(total_amount * 100);

ALTER TABLE installers
    ALTER COLUMN standard_rate TYPE BIGINT USING ROUND(standard_rate * 100);

-- installer_advance_amount / installer_final_amount carry DEFAULT 0.00; drop it
-- before the type change and restore it as an integer default afterwards.
ALTER TABLE installations ALTER COLUMN installer_advance_amount DROP DEFAULT;
ALTER TABLE installations ALTER COLUMN installer_final_amount   DROP DEFAULT;
ALTER TABLE installations
    ALTER COLUMN agreed_installer_price   TYPE BIGINT USING ROUND(agreed_installer_price * 100),
    ALTER COLUMN installer_advance_amount TYPE BIGINT USING ROUND(installer_advance_amount * 100),
    ALTER COLUMN installer_final_amount   TYPE BIGINT USING ROUND(installer_final_amount * 100);
ALTER TABLE installations ALTER COLUMN installer_advance_amount SET DEFAULT 0;
ALTER TABLE installations ALTER COLUMN installer_final_amount   SET DEFAULT 0;

ALTER TABLE installer_payments
    ALTER COLUMN amount TYPE BIGINT USING ROUND(amount * 100);
