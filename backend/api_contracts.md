# Exhaustive API Contracts

This document details all 70+ REST API contracts for the Spacesio Beryl CRM & ERP system. Base URL: `/api/v1`.

## 0. System

### Health Check
* **Endpoint:** `GET /ping`

---

### Test Ping (RabbitMQ)
* **Endpoint:** `POST /api/v1/test/ping`

---

## 1. IAM

### Login
* **Endpoint:** `POST /api/v1/login`
* **Request Payload:**
```json
{
  "email": "admin@company.com",
  "password": "admin123"
}
```

---

### Get Me
* **Endpoint:** `GET /api/v1/users/me`

---

### Setup PINs (Super Admin)
* **Endpoint:** `POST /api/v1/iam/setup-pins`
* **Request Payload:**
```json
{
  "normal_pin": "1234",
  "confirm_normal_pin": "1234",
  "high_security_pin": "567890",
  "confirm_high_security_pin": "567890"
}
```

---

### Verify PIN (Normal)
* **Endpoint:** `POST /api/v1/iam/verify-pin`
* **Request Payload:**
```json
{
  "pin": "1234"
}
```

---

### Verify PIN (Ghost Mode)
* **Endpoint:** `POST /api/v1/iam/verify-pin`
* **Request Payload:**
```json
{
  "pin": "567890"
}
```

---

### Create User
* **Endpoint:** `POST /api/v1/users`
* **Request Payload:**
```json
{
  "name": "Test Staff",
  "email": "staff@company.com",
  "password": "password123",
  "role": "staff",
  "department": "operations"
}
```

---

### List Users
* **Endpoint:** `GET /api/v1/users`

---

### Refresh Token
* **Endpoint:** `POST /api/v1/refresh`
* **Request Payload:**
```json
{
  "refresh_token": "PASTE_REFRESH_TOKEN"
}
```

---

### Change Password
* **Endpoint:** `PATCH /api/v1/users/me/password`
* **Request Payload:**
```json
{
  "old_password": "admin123",
  "new_password": "newpass123"
}
```

---

### Logout
* **Endpoint:** `POST /api/v1/logout`

---

## 2. HR - Attendance

### Check In
* **Endpoint:** `POST /api/v1/hr/attendance/check-in`
* **Request Payload:**
```json
{}
```

---

### Check In (Override)
* **Endpoint:** `POST /api/v1/hr/attendance/check-in`
* **Request Payload:**
```json
{
  "is_override_request": true,
  "override_reason": "Working from client site"
}
```

---

### Check Out
* **Endpoint:** `POST /api/v1/hr/attendance/check-out`

---

### My Attendance
* **Endpoint:** `GET /api/v1/hr/attendance/me`

---

### List All (Admin)
* **Endpoint:** `GET /api/v1/hr/attendance`

---

### List Overrides (Admin)
* **Endpoint:** `GET /api/v1/hr/attendance/overrides`

---

### Resolve Override (Admin)
* **Endpoint:** `PATCH /api/v1/hr/attendance/overrides/1`
* **Request Payload:**
```json
{
  "status": "approved"
}
```

---

## 2. HR - Leave Management

### Request Leave
* **Endpoint:** `POST /api/v1/hr/leaves`
* **Request Payload:**
```json
{
  "leave_type": "casual_leave",
  "start_date": "2026-05-10",
  "end_date": "2026-05-12",
  "reason": "Family function"
}
```

---

### My Leaves
* **Endpoint:** `GET /api/v1/hr/leaves/me`

---

### Edit Leave (User)
* **Endpoint:** `PATCH /api/v1/hr/leaves/1`
* **Request Payload:**
```json
{
  "start_date": "2026-05-11",
  "reason": "Updated reason"
}
```

---

### Cancel Leave (User)
* **Endpoint:** `PATCH /api/v1/hr/leaves/1/cancel`

---

### List All Leaves (Admin)
* **Endpoint:** `GET /api/v1/hr/leaves?status=pending`

---

### Admin Edit Leave
* **Endpoint:** `PATCH /api/v1/hr/leaves/1/admin-edit`
* **Request Payload:**
```json
{
  "leave_type": "sick_leave",
  "start_date": "2026-05-10"
}
```

---

### Approve Leave (Admin)
* **Endpoint:** `PATCH /api/v1/hr/leaves/1/status`
* **Request Payload:**
```json
{
  "status": "approved",
  "admin_remarks": "Approved, please hand over tasks"
}
```

---

### Reject Leave (Admin)
* **Endpoint:** `PATCH /api/v1/hr/leaves/1/status`
* **Request Payload:**
```json
{
  "status": "rejected",
  "admin_remarks": "Insufficient leave balance"
}
```

---

## 2. HR - Expenses

### Create Expense
* **Endpoint:** `POST /api/v1/hr/expenses`
* **Request Payload:**
```json
{
  "amount": 500.0,
  "person_paid": "Delivery Boy",
  "context": "Courier charges",
  "expense_date": "2026-05-05"
}
```

---

### List Expenses (Admin)
* **Endpoint:** `GET /api/v1/hr/expenses`

---

### Get Expense (Admin)
* **Endpoint:** `GET /api/v1/hr/expenses/1`

---

## 3. CRM - Leads

### Create Lead
* **Endpoint:** `POST /api/v1/crm/leads`
* **Request Payload:**
```json
{
  "client_name": "Rahul Sharma",
  "client_phone": "+919876543210",
  "client_email": "rahul@test.com",
  "source": "walk_in"
}
```

---

### List Leads
* **Endpoint:** `GET /api/v1/crm/leads`

---

### Get Lead
* **Endpoint:** `GET /api/v1/crm/leads/1`

---

### Assign Lead
* **Endpoint:** `PATCH /api/v1/crm/leads/1/assign`
* **Request Payload:**
```json
{
  "assigned_to": 1
}
```

---

### Update Lead Status
* **Endpoint:** `PATCH /api/v1/crm/leads/1/status`
* **Request Payload:**
```json
{
  "status": "first_call"
}
```

---

### Mark Lead Lost
* **Endpoint:** `PATCH /api/v1/crm/leads/1/status`
* **Request Payload:**
```json
{
  "status": "lost",
  "lost_reason": "Budget constraints"
}
```

---

## 3. CRM - Follow-ups

### Create Follow-up
* **Endpoint:** `POST /api/v1/crm/followups`
* **Request Payload:**
```json
{
  "lead_id": 1,
  "scheduled_for": "2026-05-06T10:00:00Z",
  "notes": "Call to discuss quotation"
}
```

---

### My Queue
* **Endpoint:** `GET /api/v1/crm/followups/my-queue`

---

### Complete Follow-up
* **Endpoint:** `PATCH /api/v1/crm/followups/1/complete`
* **Request Payload:**
```json
{
  "outcome_notes": "Client interested, sending PDF"
}
```

---

## 3. CRM - Client Complaints

### Create Client Complaint
* **Endpoint:** `POST /api/v1/crm/complaints`
* **Request Payload:**
```json
{
  "title": "Kitchen hinges loose",
  "description": "Hinges on upper cabinets are loose after 2 weeks",
  "priority": "high",
  "lead_id": 1,
  "client_name": "Rahul Sharma",
  "client_phone": "+919876543210"
}
```

---

### Create Complaint (Order-linked)
* **Endpoint:** `POST /api/v1/crm/complaints`
* **Request Payload:**
```json
{
  "title": "Wardrobe alignment issue",
  "description": "Door not closing properly",
  "priority": "medium",
  "order_id": 1
}
```

---

### List Complaints
* **Endpoint:** `GET /api/v1/crm/complaints`

---

### Assign Complaint (Admin)
* **Endpoint:** `PATCH /api/v1/crm/complaints/1/assign`
* **Request Payload:**
```json
{
  "assigned_to": 1
}
```

---

### Resolve Complaint
* **Endpoint:** `PATCH /api/v1/crm/complaints/1/status`
* **Request Payload:**
```json
{
  "status": "resolved"
}
```

---

## 3. CRM - Quotations

### Create Quotation
* **Endpoint:** `POST /api/v1/crm/leads/1/quotations`
* **Request Payload:**
```json
{
  "payment_term_type": "100_advance",
  "tax_rate": 18,
  "line_items": [
    {
      "item_name": "Modular Kitchen",
      "description": "L-shaped kitchen",
      "quantity": 1,
      "unit_price": 150000
    },
    {
      "item_name": "Wardrobe",
      "description": "3-door wardrobe",
      "quantity": 2,
      "unit_price": 35000
    }
  ]
}
```

---

### Create Cash Quotation (Ghost)
* **Endpoint:** `POST /api/v1/crm/leads/1/quotations`
* **Request Payload:**
```json
{
  "payment_term_type": "cash",
  "tax_rate": 0,
  "line_items": [
    {
      "item_name": "Custom Shelving",
      "quantity": 1,
      "unit_price": 25000
    }
  ]
}
```

---

### List Quotations (by Lead)
* **Endpoint:** `GET /api/v1/crm/leads/1/quotations`

---

### Approve Quotation (triggers Order)
* **Endpoint:** `PATCH /api/v1/crm/quotations/1/status`
* **Request Payload:**
```json
{
  "status": "client_approved"
}
```

---

## 4. Logistics - Vendors

### Create Vendor
* **Endpoint:** `POST /api/v1/logistics/vendors`
* **Request Payload:**
```json
{
  "company_name": "ABC Plywood",
  "phone": "+911234567890",
  "contact_person": "Ravi",
  "email": "ravi@abc.com",
  "default_payment_mode": "bank_transfer"
}
```

---

### List Vendors
* **Endpoint:** `GET /api/v1/logistics/vendors`

---

### Get Vendor
* **Endpoint:** `GET /api/v1/logistics/vendors/1`

---

## 4. Logistics - Orders

### List Orders
* **Endpoint:** `GET /api/v1/logistics/orders`

---

### Assign Order Manager
* **Endpoint:** `PATCH /api/v1/logistics/orders/1/assign`
* **Request Payload:**
```json
{
  "operations_manager_id": 1
}
```

---

### Create Purchase Order
* **Endpoint:** `POST /api/v1/logistics/orders/1/pos`
* **Request Payload:**
```json
{
  "vendor_id": 1,
  "total_amount": 50000,
  "expected_delivery_date": "2026-05-15"
}
```

---

## 4. Logistics - Dispatch

### Create Dispatch
* **Endpoint:** `POST /api/v1/logistics/dispatches`
* **Request Payload:**
```json
{
  "order_id": 1,
  "operations_staff_id": 1,
  "loading_responsibility": "company",
  "transport_driver_name": "Suresh",
  "transport_vehicle_no": "KA-01-1234"
}
```

---

### My Dispatches
* **Endpoint:** `GET /api/v1/logistics/dispatches/my-tasks`

---

### Log Dispatch Time
* **Endpoint:** `PATCH /api/v1/logistics/dispatches/1/log`
* **Request Payload:**
```json
{
  "type": "dispatch",
  "notes": "Left warehouse"
}
```

---

### Log Delivery Time
* **Endpoint:** `PATCH /api/v1/logistics/dispatches/1/log`
* **Request Payload:**
```json
{
  "type": "delivery",
  "notes": "Delivered to site"
}
```

---

## 5. Execution - Installers

### Create Installer
* **Endpoint:** `POST /api/v1/execution/installers`
* **Request Payload:**
```json
{
  "name": "Raju Carpenter",
  "phone": "+919988776655",
  "expertise_area": "modular_kitchen",
  "standard_rate": 800,
  "preferred_payment_mode": "upi"
}
```

---

### List Installers
* **Endpoint:** `GET /api/v1/execution/installers`

---

## 5. Execution - Jobs

### Create Installation
* **Endpoint:** `POST /api/v1/execution/orders/1/installation`
* **Request Payload:**
```json
{
  "technical_manager_id": 1
}
```

---

### List Jobs
* **Endpoint:** `GET /api/v1/execution/jobs`

---

### My Jobs
* **Endpoint:** `GET /api/v1/execution/jobs/my-tasks`

---

### Assign Installer
* **Endpoint:** `PATCH /api/v1/execution/jobs/1/assign`
* **Request Payload:**
```json
{
  "installer_id": 1,
  "agreed_installer_price": 15000,
  "estimated_completion_date": "2026-05-20"
}
```

---

### Sync Updates (Offline)
* **Endpoint:** `POST /api/v1/execution/jobs/1/updates/sync`
* **Request Payload:**
```json
{
  "updates": [
    {
      "update_time": "2026-05-05T09:00:00Z",
      "notes": "Started kitchen panel cutting"
    },
    {
      "update_time": "2026-05-05T17:00:00Z",
      "notes": "Panels cut, ready for assembly"
    }
  ]
}
```

---

### Get Updates
* **Endpoint:** `GET /api/v1/execution/jobs/1/updates`

---

### Signoff (Client Approved)
* **Endpoint:** `PATCH /api/v1/execution/jobs/1/signoff`
* **Request Payload:**
```json
{
  "client_signoff_url": "https://minio/signatures/sig1.png",
  "status": "client_approved",
  "client_feedback": "Great work!"
}
```

---

## 5. Contractors

### Update Job Status
* **Endpoint:** `PATCH /api/v1/execution/contractors/jobs/1/status`
* **Request Payload:**
```json
{
  "status": "accepted"
}
```

---

### Check In
* **Endpoint:** `POST /api/v1/execution/contractors/jobs/1/check-in`
* **Request Payload:**
```json
{
  "verification_notes": "Called at 9:30 AM, confirmed on site",
  "proof_photo_url": ""
}
```

---

### Check Out
* **Endpoint:** `POST /api/v1/execution/contractors/jobs/1/check-out`

---

### Record Advance Payment
* **Endpoint:** `POST /api/v1/execution/contractors/jobs/1/payments`
* **Request Payload:**
```json
{
  "amount": 1500,
  "payment_type": "advance",
  "payment_mode": "upi",
  "transaction_reference": "UPI-REF-001"
}
```

---

### Record Final Discharge
* **Endpoint:** `POST /api/v1/execution/contractors/jobs/1/payments`
* **Request Payload:**
```json
{
  "amount": 13500,
  "payment_type": "final_discharge",
  "payment_mode": "bank_transfer",
  "transaction_reference": "NEFT-REF-002"
}
```

---

### Get Ledger
* **Endpoint:** `GET /api/v1/execution/contractors/jobs/1/ledger`

---

