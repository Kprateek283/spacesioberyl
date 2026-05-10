# HR Feature Wireframes

## 1. HR Dashboard Page (`/hr/dashboard`)
**Layout:** Standard Scaffold.
**Components:**
- **Hero Card (Top):** "Current Status: Present / Absent".
- **Massive Action Button:** A huge circular button labeled "Check In" or "Check Out". Color toggles (Green for In, Red for Out).
  - Triggers `POST /hr/attendance/check-in` or `check-out`.
  - Also fetches `/hr/attendance/me` to show today's timestamp.
- **Quick Links Grid:** Cards for "My Leaves", "Office Expenses", "IT Support".

## 2. Attendance Admin Page (`/hr/attendance`)
**Layout:** Table view with Date filters.
**Components:**
- **Date Picker Filter:** "Select Date" (Defaults to today).
- **Tab Bar:** "All Staff" | "Pending Overrides".
- **Data Table (All Staff):** Name, Check-in time, Check-out time, IP Address Match (Green Check / Red Cross).
- **Data Table (Overrides):** List of users stuck in `pending_override`.
  - Column: "Reason" (Text).
  - **Action Buttons:** "Approve" (Green Check) / "Reject" (Red Cross).

## 3. Leave Management (Admin) Page (`/hr/leaves`)
**Layout:** Kanban Board or Tabbed List (Pending, Approved, Rejected).
**Components:**
- **Cards (Per Leave Request):** Shows User Name, Leave Type (Badge: Sick, Casual), Dates, and Reason snippet.
- **Clicking a Card opens `AdminProcessLeaveModal`.**

## 4. My Leaves Page (`/hr/my-leaves`)
**Layout:** List view of personal history.
**Components:**
- **FAB (Floating Action Button):** "Request Leave".
- **List Tile:** Start Date to End Date, Type, Status Badge (Yellow/Green/Red).
- **Action Buttons (Only visible if Pending):** "Edit" (Pencil icon) and "Cancel" (Trash icon - `PATCH /hr/leaves/:id/cancel`).

## 5. Modals & Complex Components

### Check-In Override Modal
- **Dialog Box:** "You are not on Office Wi-Fi".
- **Helper Text:** "Please provide a reason for remote check-in."
- **Input TextArea:** Override Reason (e.g., "At client site").
- **Buttons:** "Submit Request".

### Request Leave Modal
- **Dialog Box:** "Apply for Leave".
- **Dropdown:** Leave Type (Sick, Casual, Unpaid).
- **Date Range Picker Calendar:** Select Start and End Date.
- **Input TextArea:** Reason.
- **Buttons:** "Submit" (`POST /hr/leaves`).

### Admin Process Leave Modal
- **Dialog Box:** "Review Leave Request".
- **Read-Only Text:** User Name, Dates, Requested Reason.
- **Input TextArea:** Admin Remarks (Optional for approve, Required for reject).
- **Button Group:**
  - "Reject" (Red Outline - `PATCH /hr/leaves/:id/status`).
  - "Approve" (Solid Green - `PATCH /hr/leaves/:id/status`).
  - "Admin Edit" (Small text link to forcefully change dates via `PATCH /hr/leaves/:id/admin-edit`).

### Log Expense Modal
- **Dialog Box:** "Log Daily Expense".
- **Input Number:** Amount (₹).
- **Input Text:** Person Paid.
- **Input Text:** Context / Description.
- **Date Picker:** Expense Date.
- **Image Picker Component:** "Upload Receipt" (Camera icon opens device camera or gallery).
- **Buttons:** "Save Expense" (`POST /hr/expenses`).