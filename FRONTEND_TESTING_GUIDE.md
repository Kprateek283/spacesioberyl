# Spacesio Beryl: Production-Grade Frontend Testing Guide

This document provides a comprehensive, step-by-step guide to testing the production readiness of the Flutter frontend, including the necessary credentials and execution flows.

---

## 1. Test Accounts & Credentials

The backend database is automatically seeded with the following accounts upon initialization. Use these to test role-based access and features.

### Super Admin Account
* **Email**: `admin@gmail.com`
* **Password**: `admin123`
* **Role**: `super_admin` (Full access to all modules, including Admin Leave approvals and global expenses).

### Staff Account
* **Email**: `staff@gmail.com`
* **Password**: `staff123`
* **Role**: `staff` (Field/office worker access, limited to own tasks and standard operations).

---

## 2. Environment Setup

To begin testing, you must have both the backend and frontend running simultaneously.

### Start the Backend
1. Open a terminal and navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Start the Go server (it runs on port 8080 by default):
   ```bash
   go run main.go
   ```

### Start the Frontend
1. Open a second terminal and navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Ensure dependencies are up to date:
   ```bash
   flutter pub get
   ```
3. Run the application on an emulator or connected device:
   ```bash
   flutter run
   ```

---

## 3. End-to-End Testing Workflows

### A. Authentication & Ghost Mode (IAM)
1. **Login**: Launch the app and log in using `admin@gmail.com` and `admin123`.
2. **PIN Setup**: The app should prompt you to set up two PINs:
   - **Normal PIN**: For standard daily access.
   - **High-Security PIN**: For activating "Ghost Mode" (hides sensitive cash transactions).
3. **Ghost Mode Validation**: 
   - Kill the app and reopen it.
   - Enter your **High-Security PIN**.
   - Navigate to the HR Expenses or CRM Quotations screen. You should notice that cash-based options and fields are hidden (enforced by the `GhostModeAware` widget).
   - Kill the app again, reopen it, and enter your **Normal PIN** to verify those fields become visible again.

### B. HR Module
1. **Attendance**: 
   - Go to the HR Dashboard.
   - Tap **Check In**. Verify the time is logged successfully. 
   - Tap **Check Out**.
2. **Leaves**: 
   - Navigate to **My Leaves** and request a new leave.
   - Since you are logged in as an Admin, navigate to **Admin Leaves** (if exposed in the UI) and test approving your own or another user's leave.
3. **Expenses**: 
   - Navigate to **My Expenses**.
   - Tap the "+" button to create an expense.
   - Tap the image placeholder to launch the camera/gallery picker and select a receipt.
   - Enter the amount and submit. Verify it appears in your list.

### C. CRM Module
1. **Lead Generation**: 
   - Go to the CRM section and tap **Leads**. 
   - Create a new lead with dummy contact information.
2. **Quotations & Ghost Mode Check**: 
   - Tap on the newly created lead to open the Lead Details screen.
   - Tap **Create Quotation**.
   - **Standard Flow**: Select "100% Advance", enter an item name and price, and submit.
   - **Ghost Mode Flow**: Open the dialog again and select "Cash (Ghost Mode)". Ensure the Unit Price field reacts properly to your active session's mode.
   - Tap **Approve** on the standard quotation.

### D. Logistics Module
1. **Order Handoff**: 
   - Navigate to the Logistics section -> **Orders Dashboard**.
   - The quotation you just approved in the CRM should now appear here as an active order.
2. **Purchasing (PO)**: 
   - Expand the order tile and tap **Create PO**.
   - Enter a dummy Vendor ID and Amount, then submit.
3. **Dispatching**: 
   - Expand the order tile again and tap **Schedule Dispatch**.
   - Assign a Staff ID and Vehicle Number. Verify the success message.

### E. Execution & Contractors Module
1. **Contractor Directory**: 
   - Navigate to the Execution section -> **Installers**.
   - Add a new contractor (e.g., Plumber or Electrician) and specify their hourly rate.
2. **Job Management**: 
   - Navigate to a specific job in the **Execution Jobs** screen.
   - Tap **Assign Installer** and assign the contractor you just created.
3. **Field Operations**: 
   - **Check In/Out**: Test the quick action chips to check the contractor in and out of the site.
   - **Record Payment**: Tap Record Payment. Select "Cash". Verify the amount field logic.
   - **Site Updates**: Tap **Site Updates**, capture a photo of the "work done", and add notes.
   - **Sign-off**: Tap **Sign-off**, draw a signature on the canvas, and submit.

### F. Offline-First Resilience Testing
1. Disconnect your emulator/device from Wi-Fi and Cellular data.
2. Navigate to the CRM module and create a new Lead.
3. Navigate to HR and log an Expense.
4. Verify the app handles the network failure gracefully and does not crash.
5. Reconnect to the internet.
6. The app's internal `SyncService` should process the background queue and push the local mutations to the Go backend automatically. Refresh the screens to verify the data is now persistent.
