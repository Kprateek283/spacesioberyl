# API Contracts

This document details the primary REST API contracts for the Spacesio Beryl CRM & ERP system. Base URL: `/api/v1`.

---

## 1. IAM (Identity & Access Management)

### Login
*   **Endpoint:** `POST /login`
*   **Description:** Authenticates a user using email and password, returning initial JWT tokens.
*   **Request Payload:**
    ```json
    { "email": "user@company.com", "password": "password123" }
    ```
*   **Response:** `200 OK`
    ```json
    { "access_token": "...", "refresh_token": "...", "user": { "id": 1, "role": "super_admin", ... } }
    ```

### Verify PIN
*   **Endpoint:** `POST /iam/verify-pin`
*   **Description:** Validates user PIN. Injects `ghost_mode: true` if the high-security PIN is used by Super Admin.
*   **Request Payload:** `{ "pin": "1234" }`
*   **Response:** `200 OK` `{ "token": "..." }`

### Create User (Admin Only)
*   **Endpoint:** `POST /users`
*   **Request Payload:**
    ```json
    { "name": "John", "email": "john@company.com", "password": "temp", "role": "staff", "department": "sales" }
    ```
*   **Response:** `201 Created`

---

## 2. HR Module

### Attendance Check-In
*   **Endpoint:** `POST /hr/attendance/check-in`
*   **Description:** Logs check-in time. Rejects if already checked in. Validates IP.
*   **Request Payload:** `{ "ip_address": "192.168.1.100" }`
*   **Response:** `200 OK`

### Attendance Check-Out
*   **Endpoint:** `POST /hr/attendance/check-out`
*   **Response:** `200 OK`

### Request Leave
*   **Endpoint:** `POST /hr/leaves`
*   **Request Payload:**
    ```json
    { "leave_type": "sick_leave", "start_date": "YYYY-MM-DD", "end_date": "YYYY-MM-DD", "reason": "..." }
    ```
*   **Response:** `201 Created`

### Log Expense
*   **Endpoint:** `POST /hr/expenses`
*   **Request Payload:**
    ```json
    { "amount": 100.0, "paid_to": "Vendor X", "context": "Office supplies", "expense_date": "YYYY-MM-DD", "receipt_url": "..." }
    ```
*   **Response:** `201 Created`

---

## 3. CRM Module

### Create Lead
*   **Endpoint:** `POST /crm/leads`
*   **Request Payload:**
    ```json
    { "client_name": "Acme", "client_email": "...", "client_phone": "...", "source": "website" }
    ```
*   **Response:** `201 Created`

### Update Lead Status
*   **Endpoint:** `PATCH /crm/leads/:id/status`
*   **Request Payload:** `{ "status": "negotiation" }`
*   **Response:** `200 OK`

### Create Quotation
*   **Endpoint:** `POST /crm/leads/:id/quotations`
*   **Request Payload:**
    ```json
    {
      "amount": 1000.0,
      "tax_percentage": 10.0,
      "payment_term_type": "advance",
      "items": [ { "name": "Item A", "quantity": 1, "unit_price": 1000.0 } ]
    }
    ```
*   **Response:** `201 Created`

---

## 4. Logistics Module

### Get Orders
*   **Endpoint:** `GET /logistics/orders`
*   **Response:** `200 OK` (Returns list of orders ready for procurement/dispatch).

### Log Dispatch/Delivery
*   **Endpoint:** `PATCH /logistics/dispatches/:id/log`
*   **Request Payload:** `{ "type": "dispatch" }` or `{ "type": "delivery" }`
*   **Response:** `200 OK`

---

## 5. Execution Module

### Create Installation
*   **Endpoint:** `POST /execution/orders/:id/installation`
*   **Request Payload:** `{ "technical_manager_id": 1 }`
*   **Response:** `201 Created`

### Contractor Check-In
*   **Endpoint:** `POST /execution/contractors/jobs/:id/check-in`
*   **Description:** Manual verification by manager.
*   **Request Payload:** `{ "verification_notes": "...", "proof_photo_url": "..." }`
*   **Response:** `200 OK`

### Sync Offline Site Updates
*   **Endpoint:** `POST /execution/jobs/:id/updates/sync`
*   **Request Payload:** `{ "notes": "...", "photo_url": "...", "timestamp": "..." }`
*   **Response:** `200 OK`

### Client Signoff (Financial Lock)
*   **Endpoint:** `PATCH /execution/jobs/:id/signoff`
*   **Request Payload:** `{ "signature_url": "..." }`
*   **Response:** `200 OK`