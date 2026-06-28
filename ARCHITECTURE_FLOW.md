# Architecture & Feature Flow

This document maps the flow of data across the tech stack for each major feature in the Spacesio Beryl application.

## 1. Authentication (IAM)
* **Frontend (Flutter):** Submits credentials. Retrieves JWT and stores it in secure storage. Passes token in `Authorization` header.
* **Backend (Go):** Validates credentials using `bcrypt`. Generates JWT. If a Ghost Mode PIN is used, it injects `"ghost_mode": true` into the JWT claims.
* **Database (PostgreSQL):** Stores user records, roles, and salted PIN hashes.

## 2. CRM & Sales
* **Frontend:** Managers create leads, follow-ups, and quotations. Quotations with cash terms are visually hidden in Ghost Mode.
* **Backend:** Exposes REST endpoints to update CRM states. Validates that `lost` leads have a reason.
* **Database:** `leads`, `followups`, and `quotations` tables maintain foreign key relationships.
* **RabbitMQ:** When a Quotation is marked as `client_approved`, the backend publishes a `quote_approved` event to RabbitMQ. A background worker consumes this event and automatically creates an Order in the Logistics schema.

## 3. Logistics
* **Frontend:** Provides dashboards for Orders, Vendors, and Dispatches. Includes an offline-first mechanism for logging deliveries when out of network coverage.
* **Backend:** Processes Dispatches.
* **Database:** Stores `vendors`, `orders`, and `dispatches`.

## 4. Execution (Installations)
* **Frontend:** Tech managers assign contractors, log presence, and upload site photos. Provides a signature canvas for client signoff.
* **MinIO:** Stores site photos and the final client signature PNG.
* **Backend:** Blocks the `final_discharge` payment type unless the job status is explicitly `client_approved`.
* **Database:** Maintains ledgers, site updates, and contractor registries.

## 5. HR (Expenses & Leaves)
* **Frontend:** Employees upload receipts and request leaves.
* **MinIO:** Stores expense receipts securely.
* **Backend:** Evaluates IP addresses for attendance check-ins to flag off-site check-ins for manual approval.
* **Database:** Uses `ON CONFLICT DO NOTHING` logic to enforce one attendance record per day.
