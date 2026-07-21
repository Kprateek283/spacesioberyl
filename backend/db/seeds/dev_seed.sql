-- Development seed data for Spacesio Beryl CRM.
--
-- Re-runnable: truncates all data tables (but not `roles`, which migration
-- 000002 owns, or `schema_migrations`) and reinserts with fixed IDs.
--
-- NOT FOR PRODUCTION. Every account shares the password `Password123!`.
--
-- The quotation and order fixtures are deliberately built so the ghost-mode
-- cash filter is observable — see the "GHOST MODE FIXTURES" note below.

BEGIN;

TRUNCATE
    installation_updates, installer_payments, installer_daily_logs,
    installations, dispatches, purchase_orders, orders,
    quotation_line_items, quotations, follow_ups, client_complaints,
    project_documents, leads, installers, vendors,
    office_expenses, hr_leaves, attendances, users
    RESTART IDENTITY CASCADE;

-- =====================================================
-- Users — password for all accounts is `Password123!`
-- Only the super_admin has PINs, because IAMService.SetupPins refuses to
-- store them for any other role. Normal PIN 1234 (ghost_mode=false),
-- high-security PIN 654321 (ghost_mode=true, cash visible).
-- =====================================================
INSERT INTO users (id, name, email, password_hash, role_id, department, is_active, pin_hash, high_security_pin_hash) VALUES
(1, 'Ananya Rao',     'super@spacesio.test',    '$2a$10$LUbTYMGgUj7BnN7Y9uCil.OtJ94YVyDzMqF3ZcZyijc2x50seGIcm', 1, 'management', true,
    '$2a$10$4Ou99MvcXc1rE2.8PVi77ORCS13hVtD1Ik0F.XNeV8FbVrl.FVd6W',
    '$2a$10$3fv6LkUGZsS41EAO9PGrVu78Wko3ADj.qhh0stFLHkVMzBD0jtfQu'),
(2, 'Vikram Sethi',   'admin@spacesio.test',    '$2a$10$LUbTYMGgUj7BnN7Y9uCil.OtJ94YVyDzMqF3ZcZyijc2x50seGIcm', 2, 'management', true, NULL, NULL),
(3, 'Priya Nambiar',  'sales@spacesio.test',    '$2a$10$LUbTYMGgUj7BnN7Y9uCil.OtJ94YVyDzMqF3ZcZyijc2x50seGIcm', 3, 'sales',      true, NULL, NULL),
(4, 'Rahul Deshmukh', 'ops@spacesio.test',      '$2a$10$LUbTYMGgUj7BnN7Y9uCil.OtJ94YVyDzMqF3ZcZyijc2x50seGIcm', 3, 'operations', true, NULL, NULL),
(5, 'Farhan Qureshi', 'tech@spacesio.test',     '$2a$10$LUbTYMGgUj7BnN7Y9uCil.OtJ94YVyDzMqF3ZcZyijc2x50seGIcm', 3, 'technical',  true, NULL, NULL),
(6, 'Meera Iyer',     'accounts@spacesio.test', '$2a$10$LUbTYMGgUj7BnN7Y9uCil.OtJ94YVyDzMqF3ZcZyijc2x50seGIcm', 3, 'accounts',   true, NULL, NULL),
(7, 'Sunil Bhatia',   'inactive@spacesio.test', '$2a$10$LUbTYMGgUj7BnN7Y9uCil.OtJ94YVyDzMqF3ZcZyijc2x50seGIcm', 3, 'sales',      false, NULL, NULL);
SELECT setval('users_id_seq', 7);

-- =====================================================
-- Leads
-- =====================================================
INSERT INTO leads (id, client_name, client_phone, client_email, source, assigned_to, status, lost_reason) VALUES
(1, 'Meridian Offices',   '+91 98200 11001', 'facilities@meridian.test', 'referral',     3, 'approved', NULL),
(2, 'Kalyani Residency',  '+91 98200 11002', 'admin@kalyani.test',       'walk_in',      3, 'approved', NULL),
(3, 'Nexus Retail',       '+91 98200 11003', 'projects@nexus.test',      'website',      3, 'approved', NULL),
(4, 'Aurora Clinics',     '+91 98200 11004', 'ops@aurora.test',          'website',      3, 'new',      NULL),
(5, 'Bluestone Partners', '+91 98200 11005', NULL,                       'cold_call',    3, 'rejected', 'Chose a competitor on price');
SELECT setval('leads_id_seq', 5);

-- =====================================================
-- Quotations — GHOST MODE FIXTURES
--
-- Lead 1: approved ONLINE quote        -> pipeline value 450000.00 for everyone
-- Lead 2: approved CASH quote only     -> pipeline value 0 without ghost mode,
--                                         275000.00 with it. This row is the
--                                         discriminator: if it is visible to a
--                                         non-super_admin, the filter is broken.
-- Lead 3: approved ONLINE quote        -> drives the deep pipeline below
-- Lead 4: draft quote, never approved  -> contributes no pipeline value
-- =====================================================
INSERT INTO quotations (id, lead_id, created_by, subtotal, tax_rate, tax_amount, total_amount, payment_term_type, payment_term_details, status) VALUES
-- Money columns are BIGINT paise (backend-bugs #15); tax_rate stays a percentage.
(1, 1, 3, 38135593, 18.00,  6864407, 45000000, 'bank_transfer', '{"milestones":[{"label":"Advance","percent":40},{"label":"On delivery","percent":60}]}', 'approved'),
(2, 2, 3, 23305085, 18.00,  4194915, 27500000, 'cash',          '{"note":"Full settlement on handover"}',                                              'approved'),
(3, 3, 3, 32203390, 18.00,  5796610, 38000000, 'upi',           '{"milestones":[{"label":"Advance","percent":50},{"label":"On completion","percent":50}]}', 'approved'),
(4, 4, 3,  8474576, 18.00,  1525424, 10000000, 'bank_transfer', '{}',                                                                                  'draft'),
(5, 5, 3, 16949153, 18.00,  3050847, 20000000, 'cash',          '{"note":"Client declined"}',                                                          'rejected');
SELECT setval('quotations_id_seq', 5);

INSERT INTO quotation_line_items (quotation_id, item_name, description, quantity, unit_price, total_price) VALUES
(1, 'Workstation cluster', '6-seat modular cluster, laminate finish', 8,  3800000, 30400000),
(1, 'Task chairs',         'Mesh-back, adjustable lumbar',            24,  322316,  7735593),
(2, 'Modular wardrobe',    'Three-door, soft-close',                  5,  3100000, 15500000),
(2, 'Kitchen cabinetry',   'Base and wall units, acrylic finish',     1,  7805085,  7805085),
(3, 'Retail display bays', 'Backlit, powder-coated steel',            11, 2400000, 26400000),
(3, 'Checkout counters',   'Laminate top, cable management',          2,  2901695,  5803390),
(4, 'Reception desk',      'Curved, solid surface top',               1,  8474576,  8474576);

-- =====================================================
-- Orders — lead 2's order is CASH, and is the order-level filter discriminator
-- =====================================================
INSERT INTO orders (id, quotation_id, lead_id, operations_manager_id, status, payment_term_type) VALUES
(1, 1, 1, 4, 'dispatched',   'bank_transfer'),
(2, 2, 2, 4, 'procurement',  'cash'),
(3, 3, 3, 4, 'completed',    'upi');
SELECT setval('orders_id_seq', 3);

-- =====================================================
-- Vendors and purchase orders
-- =====================================================
INSERT INTO vendors (id, company_name, contact_person, phone, email, tax_id, default_payment_mode, address, is_active) VALUES
(1, 'Ply & Panel Traders',  'Nitin Shah',    '+91 98330 22001', 'sales@plypanel.test',  '27AABCP1234C1Z5', 'bank_transfer', 'Unit 14, Bhiwandi Industrial Estate', true),
(2, 'Sundar Hardware Co',   'Lakshmi Menon', '+91 98330 22002', 'orders@sundarhw.test', '29AABCS5678D1Z2', 'upi',           '3rd Cross, Peenya, Bengaluru',        true),
(3, 'Crestline Upholstery', 'Imran Shaikh',  '+91 98330 22003', NULL,                   NULL,              'cash',          'Shop 7, Kurla West, Mumbai',          false);
SELECT setval('vendors_id_seq', 3);

INSERT INTO purchase_orders (id, order_id, vendor_id, created_by, total_amount, status, payment_status, expected_delivery_date) VALUES
(1, 1, 1, 4, 18600000, 'received',  'paid',    CURRENT_DATE - 9),
(2, 1, 2, 4,  4250000, 'received',  'paid',    CURRENT_DATE - 7),
(3, 3, 1, 4, 14100000, 'received',  'paid',    CURRENT_DATE - 21),
(4, 2, 3, 4,  6100000, 'ordered',   'pending', CURRENT_DATE + 6);
SELECT setval('purchase_orders_id_seq', 4);

-- =====================================================
-- Installers and installations
-- =====================================================
INSERT INTO installers (id, name, phone, expertise_area, standard_rate, preferred_payment_mode, is_active) VALUES
(1, 'Ganesh Fitting Works', '+91 99870 33001', 'modular_furniture', 240000, 'upi',  true),
(2, 'Salim & Sons',         '+91 99870 33002', 'electrical',        290000, 'cash', true),
(3, 'Precision Interiors',  '+91 99870 33003', 'glass_partition',   330000, 'bank_transfer', true);
SELECT setval('installers_id_seq', 3);

INSERT INTO installations (id, order_id, technical_manager_id, installer_id, agreed_installer_price, start_date, estimated_completion_date, status, installer_job_status, installer_advance_amount, installer_final_amount, client_signoff_url, client_feedback) VALUES
(1, 1, 5, 1, 4600000, CURRENT_DATE - 4, CURRENT_DATE + 2, 'in_progress', 'checked_in', 1800000, NULL,      NULL, NULL),
(2, 3, 5, 3, 5800000, CURRENT_DATE - 24, CURRENT_DATE - 18, 'completed',  'completed',  2200000, 3600000, 'https://storage.local/crm-files/signoffs/3/signed.png', 'Clean finish, on schedule.');
SELECT setval('installations_id_seq', 2);

INSERT INTO installation_updates (installation_id, logged_by, update_time, notes, photo_url) VALUES
(1, 5, NOW() - INTERVAL '3 days', 'Cluster frames positioned, awaiting worktops.', NULL),
(1, 5, NOW() - INTERVAL '1 day',  'Worktops fitted on 5 of 8 clusters.',           NULL),
(2, 5, NOW() - INTERVAL '20 days','Display bays mounted and levelled.',            NULL),
(2, 5, NOW() - INTERVAL '18 days','Client walkthrough completed, signed off.',     NULL);

-- =====================================================
-- Dispatches
-- =====================================================
INSERT INTO dispatches (order_id, operations_staff_id, loading_responsibility, transport_driver_name, transport_vehicle_no, transport_phone, dispatch_time, delivery_time, status, notes) VALUES
(1, 4, 'vendor',  'Ravi Kadam',   'MH-04-DT-8821', '+91 99201 44001', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days' + INTERVAL '6 hours', 'delivered',  'Delivered to site gate, received by facilities.'),
(3, 4, 'in_house','Salim Ansari', 'MH-01-CX-4410', '+91 99201 44002', NOW() - INTERVAL '25 days', NOW() - INTERVAL '25 days' + INTERVAL '4 hours', 'delivered', NULL),
(2, 4, 'vendor',  NULL,           NULL,            NULL,              NULL, NULL, 'pending', 'Awaiting cabinetry from vendor.');

-- =====================================================
-- Follow-ups and complaints
-- =====================================================
INSERT INTO follow_ups (lead_id, created_by, scheduled_for, notes, status, completed_at, outcome_notes) VALUES
(4, 3, NOW() + INTERVAL '1 day',  'Send revised reception desk options.',   'pending',   NULL, NULL),
(2, 3, NOW() + INTERVAL '3 days', 'Confirm cabinetry delivery window.',     'pending',   NULL, NULL),
(1, 3, NOW() - INTERVAL '8 days', 'Walk through the approved layout.',      'completed', NOW() - INTERVAL '8 days', 'Client approved without changes.'),
(5, 3, NOW() - INTERVAL '2 days', 'Final attempt before marking lost.',     'completed', NOW() - INTERVAL '2 days', 'Went with a competitor.');

INSERT INTO client_complaints (created_by, assigned_to, title, description, status, priority, lead_id, order_id, client_name, client_phone) VALUES
(3, 5, 'Chair armrest wobble',     'Four task chairs have loose armrests after two weeks of use.', 'in_progress', 'medium', 1, 1, 'Meridian Offices', '+91 98200 11001'),
(3, NULL, 'Delivery date slipped', 'Cabinetry delivery pushed twice with no notice.',              'pending',     'high',   2, 2, 'Kalyani Residency','+91 98200 11002'),
(4, 5, 'Scuff on display bay',     'Minor scuff on the third bay, client requests touch-up.',      'resolved',    'low',    3, 3, 'Nexus Retail',     '+91 98200 11003');

-- =====================================================
-- Project documents
-- Attribution is varied on purpose: backend-bugs.md #2 was that every upload
-- was written as uploaded_by = 1, so uniform attribution here would hide it.
-- =====================================================
INSERT INTO project_documents (project_id, file_url, document_type, uploaded_by) VALUES
(1, 'https://storage.local/crm-files/projects/1/site-survey.pdf',   'site_survey',   3),
(1, 'https://storage.local/crm-files/projects/1/final-layout.pdf',  'layout',        5),
(2, 'https://storage.local/crm-files/projects/2/floor-plan.pdf',    'layout',        3),
(3, 'https://storage.local/crm-files/projects/3/signed-handover.pdf','handover',     5),
(3, 'https://storage.local/crm-files/projects/3/warranty-card.pdf', 'warranty',      4);

-- =====================================================
-- HR — attendance, leaves, office expenses
-- =====================================================
INSERT INTO attendances (user_id, date, check_in_time, check_out_time, status, ip_address, is_office_wifi, override_reason, override_status, reviewed_by) VALUES
(3, CURRENT_DATE - 1, NOW() - INTERVAL '1 day' - INTERVAL '9 hours', NOW() - INTERVAL '1 day' - INTERVAL '1 hour', 'present', '192.168.1.42',  true,  NULL, NULL, NULL),
(4, CURRENT_DATE - 1, NOW() - INTERVAL '1 day' - INTERVAL '9 hours', NOW() - INTERVAL '1 day' - INTERVAL '2 hours', 'present', '192.168.1.51',  true,  NULL, NULL, NULL),
(5, CURRENT_DATE - 1, NOW() - INTERVAL '1 day' - INTERVAL '8 hours', NOW() - INTERVAL '1 day' - INTERVAL '1 hour', 'present', '203.0.113.77',  false, 'On site at Nexus Retail all day', 'approved', 2),
(3, CURRENT_DATE,     NOW() - INTERVAL '4 hours', NULL,                                                            'present', '192.168.1.42',  true,  NULL, NULL, NULL),
(4, CURRENT_DATE,     NOW() - INTERVAL '3 hours', NULL,                                                            'present', '198.51.100.23', false, 'Vendor visit in Bhiwandi', 'pending', NULL),
(6, CURRENT_DATE - 2, NULL, NULL,                                                                                  'absent',  NULL,            false, NULL, NULL, NULL);

INSERT INTO hr_leaves (user_id, leave_type, start_date, end_date, reason, status, approved_by, admin_remarks) VALUES
(3, 'casual',  CURRENT_DATE + 5,  CURRENT_DATE + 6,  'Family function out of town.',        'pending',  NULL, NULL),
(4, 'sick',    CURRENT_DATE - 10, CURRENT_DATE - 9,  'Viral fever, doctor advised rest.',   'approved', 2,    'Get well soon.'),
(5, 'casual',  CURRENT_DATE - 30, CURRENT_DATE - 28, 'Personal work.',                      'rejected', 2,    'Two installers already on leave that week.'),
(6, 'earned',  CURRENT_DATE + 20, CURRENT_DATE + 24, 'Annual holiday.',                     'pending',  NULL, NULL);

INSERT INTO office_expenses (logged_by, amount, person_paid, context, expense_date, receipt_url) VALUES
(4, 185000, 'Ravi Kadam',      'Site transport for Meridian delivery',      CURRENT_DATE - 5,  NULL),
(6, 430000, 'Sundar Hardware', 'Replacement fittings, petty purchase',      CURRENT_DATE - 3,  'https://storage.local/crm-files/receipts/exp-2.jpg'),
(4,  62000, 'Local courier',   'Document dispatch to Nexus Retail',         CURRENT_DATE - 2,  NULL),
(6, 1250000,'Crestline Upholstery', 'Advance for chair rework',             CURRENT_DATE - 1,  'https://storage.local/crm-files/receipts/exp-4.jpg');

COMMIT;
