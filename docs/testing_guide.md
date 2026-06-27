# System Testing Guide

This document provides a step-by-step guide and credentials for testing the Spaces.io ERP System (Backend and Frontend).

## 1. System Credentials
Here are the default seed credentials found in the system for testing purposes:

> [!NOTE]
> These credentials can be used to log into the frontend web application.

### Super Admin / Admin Account
- **Email:** `admin@gmail.com`
- **Password:** `admin123`

### Staff Account (Example)
- **Email:** `staff@gmail.com`
- **Password:** `staff123`

*(Note: You can create more users from the IAM module in the frontend using the Admin account).*

---

## 2. Prerequisites & Running the System

To test the application, make sure both the backend and frontend are running.

### Start the Backend Services
The backend is fully containerized with Docker.
```bash
cd backend
docker-compose up --build -d
```
This starts:
- API Server (`:8080`)
- PostgreSQL Database
- Redis
- RabbitMQ
- MinIO (Object Storage)

### Start the Frontend Client
The frontend is a Flutter web application.
```bash
cd frontend
flutter run -d chrome
```

---

## 3. Step-by-Step Testing Flow

### Step 1: Authentication & IAM (Identity and Access Management)
1. Open the frontend in Chrome.
2. Login using the Admin credentials: `admin@company.com` / `newpass123`.
3. Navigate to the **IAM / Users** section.
4. Verify you can see a list of users.
5. Create a new user (assign them a role like `staff` and a department like `operations`).

### Step 2: CRM Module
1. Navigate to the **CRM** section.
2. Create a new Client.
3. Generate a new Quotation for the client.
4. Verify that the quotation status can be updated to `approved`.

### Step 3: Logistics Module
1. Navigate to the **Logistics** section.
2. View the active orders (these are generated from approved CRM quotations).
3. Try assigning an operations manager to an order.
4. Create a Purchase Order (PO) and select a Vendor.
5. Schedule a dispatch for the order.

### Step 4: HR Module
1. Log out from the Admin account.
2. Log back in using the Staff credentials (`staff2@company.com` / `password123`).
3. Navigate to the **HR** section.
4. Attempt to punch in (Clock In) for attendance.
5. Apply for a Leave and verify the request is recorded.
6. Submit a Complaint or Grievance ticket.

### Step 5: API Testing (Optional)
If you prefer testing the APIs directly without the frontend:
- Use the **Postman Collection** located in the root directory: `Spacesio_Beryl_Postman.json` or `test_collection.json`.
- Or run the bash script: `./test.sh` in the root folder to perform a quick automated flow testing via `curl`.
