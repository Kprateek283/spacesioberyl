# Spacesio Beryl CRM - QA Test Matrix v2

> **Purpose:** Button-by-button test plan. Fill "Actual Output" column during live testing.

---

## 1. AUTH MODULE

### 1.1 Login Screen (`login_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| A01 | **Log In** | Login | email + password | JWT returned, redirect to PIN Entry/Setup | |
| A02 | **Log In** (empty) | Login | blank fields | Form validation error "Required" | |
| A03 | **Log In** (bad creds) | Login | wrong password | Snackbar error from API | |
| A04 | **Forgot?** link | Login | none | Opens "Reset Password" dialog | |
| A05 | **Send OTP** | Forgot dialog | email | POST `/password/forgot`, shows Reset dialog | |
| A06 | **Send OTP** (empty) | Forgot dialog | blank | No action (guard) | |
| A07 | **Cancel** | Forgot dialog | none | Dialog closes | |
| A08 | **Reset Password** | Reset dialog | email+OTP+new_pass | POST `/password/reset`, success snackbar | |
| A09 | **Reset Password** (empty) | Reset dialog | missing fields | No action (guard) | |
| A10 | **Cancel** | Reset dialog | none | Dialog closes | |

### 1.2 PIN Setup Screen (`pin_setup_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| A11 | **Complete Setup** | PIN Setup | normal_pin + hs_pin | PINs saved, redirect to main app | |
| A12 | **Complete Setup** (empty) | PIN Setup | blank fields | Error "Please fill all fields" | |

### 1.3 PIN Entry Screen (`pin_entry_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| A13 | **Unlock** | PIN Entry | valid normal PIN | Session unlocked, GhostMode=false | |
| A14 | **Unlock** | PIN Entry | valid HS PIN | Session unlocked, GhostMode=true | |
| A15 | **Unlock** (wrong) | PIN Entry | bad PIN | Error snackbar, PIN cleared | |
| A16 | **Logout** | PIN Entry | none | Token cleared, back to Login | |
| A17 | **Enter key** submit | PIN Entry | PIN + Enter | Same as Unlock button | |

---

## 2. ADMIN DASHBOARD (`admin_dashboard_screen.dart`)

### 2.1 AppBar Actions

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| D01 | **Refresh** icon | Dashboard AppBar | none | Reloads daily report + pending overrides | |
| D02 | **Logout** icon | Dashboard AppBar | none | Clears auth, back to Login | |

### 2.2 Tabs

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| D03 | **Today's Report** tab | Dashboard | none | Shows summary cards + employee list | |
| D04 | **Pending Requests** tab | Dashboard | none | Shows pending override requests | |

### 2.3 Today's Report Tab

| # | Element | Page | Input | Expected Output | Actual Output |
|---|---------|------|-------|-----------------|---------------|
| D05 | Summary cards | Report tab | none | Present/Override/Offsite/Absent counts | |
| D06 | Employee rows | Report tab | none | Name, status badge, check-in/out times | |
| D07 | Pull-to-refresh | Report tab | swipe down | Reloads dashboard data | |

### 2.4 Pending Requests Tab

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| D08 | **Approve** | Pending tab | override ID | PUT review, success snackbar, list refreshes | |
| D09 | **Reject** | Pending tab | override ID | Opens reject modal | |
| D10 | **CONFIRM REJECT** | Reject modal | reason text | PUT review with feedback, success snackbar | |
| D11 | **CONFIRM REJECT** (empty) | Reject modal | blank reason | Button disabled (null onSubmit) | |
| D12 | **Cancel** | Reject modal | none | Dialog closes | |

### 2.5 FAB

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| D13 | **Add Staff** FAB | Dashboard | none | Navigates to IAM Users screen | |

---

## 3. STAFF HOME (`staff_home_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| S01 | **Logout** icon | Staff Home AppBar | none | Clears auth, back to Login | |
| S02 | **Check-In** | Staff Home | none | POST check-in, success snackbar | |
| S03 | **Check-Out** | Staff Home | none | POST check-out, success snackbar | |
| S04 | **Working off-site?** link | Staff Home | none | Opens Off-site Pass bottom sheet | |
| S05 | **Start Time** picker | Override modal | tap | Opens TimePicker | |
| S06 | **End Time** picker | Override modal | tap | Opens TimePicker | |
| S07 | **Submit Request** | Override modal | times + reason | POST override, success snackbar, modal closes | |
| S08 | **My Attendance** tile | Quick Links | none | Navigates to MyAttendanceScreen | |
| S09 | **My Leaves** tile | Quick Links | none | Navigates to MyLeavesScreen | |
| S10 | **My Expenses** tile | Quick Links | none | Navigates to MyExpensesScreen | |

---

## 4. BOTTOM NAVIGATION (`main_shell_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| N01 | **Team/Home** tab | Nav bar | none | Routes to `/` (Admin Dashboard or Staff Home) | |
| N02 | **CRM** tab | Nav bar | none | Routes to `/crm` (Leads screen) | |
| N03 | **Logistics** tab | Nav bar | none | Routes to `/logistics` (Hub screen) | |
| N04 | **Execution** tab | Nav bar | none | Routes to `/execution` (Hub screen) | |
| N05 | **More** tab | Nav bar | none | Routes to `/more` (More Menu) | |

---

## 5. MORE MENU (`more_menu_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| M01 | **My Attendance** | More Menu | none | Push MyAttendanceScreen | |
| M02 | **My Leaves** | More Menu | none | Push MyLeavesScreen | |
| M03 | **My Expenses** | More Menu | none | Push MyExpensesScreen | |
| M04 | **Follow-ups** | More Menu | none | Push CrmFollowupsScreen | |
| M05 | **Complaints** | More Menu | none | Push CrmComplaintsScreen | |
| M06 | **Profile** | More Menu | none | Push ProfileScreen | |
| M07 | **Leave Admin** (admin) | More Menu | none | Push AdminLeavesScreen | |
| M08 | **Expense Ledger** (admin) | More Menu | none | Push AdminExpensesScreen | |
| M09 | **User Management** (admin) | More Menu | none | Push IamUsersScreen | |

---

## 6. CRM MODULE

### 6.1 Leads List (`crm_leads_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| C01 | **Filter chips** (All/New/etc) | CRM Leads | tap chip | Filters leads by status | |
| C02 | **View** button on card | CRM Leads | lead ID | Navigates to LeadDetailScreen | |
| C03 | **+ FAB** | CRM Leads | none | Opens Create Lead dialog | |
| C04 | **Create** (dialog) | Create Lead | name+phone+email+source | POST lead, refreshes cache, success snackbar | |
| C05 | **Create** (empty) | Create Lead | missing name/phone | Error "Name and phone are required" | |
| C06 | **Cancel** (dialog) | Create Lead | none | Dialog closes | |
| C07 | Pull-to-refresh | CRM Leads | swipe | Refreshes leads cache | |

### 6.2 Lead Detail (`crm_lead_detail_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| C08 | **Status chips** (New, First Call, etc) | Lead Detail | tap | PUT status update, reload | |
| C09 | **Lost** chip | Lead Detail | tap | Opens "Mark Lost" dialog with reason | |
| C10 | **Confirm** (lost dialog) | Mark Lost | reason text | PUT status=lost + reason, reload | |
| C11 | **Cancel** (lost dialog) | Mark Lost | none | Dialog closes | |
| C12 | **Create Quotation** button | Lead Detail | none | Opens quotation dialog | |
| C13 | **Payment term** dropdown | Quotation dialog | select | Changes term; "cash" shows GhostMode wrapper | |
| C14 | **Add Item** button | Quotation dialog | none | Adds new line item row | |
| C15 | **Remove item** icon | Quotation dialog | tap | Removes line item row | |
| C16 | **Create** (quotation) | Quotation dialog | items+term | POST quotation, reload, success snackbar | |
| C17 | **Create** (invalid) | Quotation dialog | missing fields | Error "Invalid item details" | |
| C18 | **Approve** button | Quotation list | quotation ID | PUT approve, reload, success snackbar | |
| C19 | Pull-to-refresh | Lead Detail | swipe | Reloads lead + quotations | |

### 6.3 Follow-ups (`crm_followups_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| C20 | **Complete** (check icon) | Follow-ups | tap | Opens "Complete Follow-up" dialog | |
| C21 | **Complete** (dialog) | Complete dialog | outcome notes | PUT complete, invalidate, success | |
| C22 | **Cancel** (dialog) | Complete dialog | none | Dialog closes | |
| C23 | **Row tap** | Follow-ups | lead_id | Navigates to LeadDetailScreen | |
| C24 | Pull-to-refresh | Follow-ups | swipe | Invalidates provider | |

### 6.4 Complaints (`crm_complaints_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| C25 | **+ FAB** | Complaints | none | Opens "New Complaint" dialog | |
| C26 | **Submit** (dialog) | New Complaint | title+desc+priority | POST complaint, invalidate, success | |
| C27 | **Submit** (empty) | New Complaint | missing fields | Error "Title and description required" | |
| C28 | **Resolve** (done_all icon) | Complaints | complaint ID | PUT resolve, invalidate, success | |
| C29 | Pull-to-refresh | Complaints | swipe | Invalidates provider | |

---

## 7. HR MODULE

### 7.1 My Attendance (`my_attendance_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| H01 | **Check In** | My Attendance | none | POST check-in, refresh cache, success | |
| H02 | **Check Out** | My Attendance | none | POST check-out, refresh cache, success | |
| H03 | Status card | My Attendance | none | Shows CHECKED IN/OUT, times, hours | |
| H04 | Entries list | My Attendance | none | Shows today's check-in/out entries | |

### 7.2 My Leaves (`my_leaves_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| H05 | **+ FAB** | My Leaves | none | Opens "Request Leave" dialog | |
| H06 | **Start Date** picker | Leave dialog | tap | Opens DatePicker | |
| H07 | **End Date** picker | Leave dialog | tap | Opens DatePicker | |
| H08 | **Request** (dialog) | Leave dialog | dates+reason | POST leave, refresh, success | |
| H09 | **Request** (no dates) | Leave dialog | missing dates | Error "Start/End date required" | |
| H10 | **Cancel Request** | Leave card | pending leave ID | DELETE/cancel leave, refresh, success | |
| H11 | Balance card | My Leaves | none | Shows Total/Used/Available counts | |

### 7.3 My Expenses (`my_expenses_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| H12 | **+ FAB** | My Expenses | none | Opens "Create Expense" dialog | |
| H13 | **Receipt upload** | Expense dialog | tap | Opens image picker (gallery) | |
| H14 | **Create** (dialog) | Expense dialog | desc+amount+person | POST expense, refresh, success | |
| H15 | **Create** (empty) | Expense dialog | missing fields | Validation errors | |
| H16 | **Filter chips** | My Expenses | tap | Filters by status | |
| H17 | Summary card | My Expenses | none | Shows Total / Submitted amounts | |

### 7.4 Admin Leaves (`admin_leaves_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| H18 | **Filter chips** (pending/approved/rejected) | Admin Leaves | tap | Filters leave list | |
| H19 | **Approve** button | Admin Leaves | leave ID | PUT approved, invalidate, success | |
| H20 | **Reject** button | Admin Leaves | leave ID | Opens reject dialog | |
| H21 | **Reject** (dialog) | Reject dialog | reason | PUT rejected + remarks, success | |
| H22 | Pull-to-refresh | Admin Leaves | swipe | Invalidates provider | |

### 7.5 Admin Expenses (`admin_expenses_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| H23 | Expense list | Admin Expenses | none | Shows all expenses with amount/person/date | |
| H24 | Pull-to-refresh | Admin Expenses | swipe | Invalidates provider | |

---

## 8. IAM MODULE

### 8.1 User Management (`iam_users_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| I01 | **+ FAB** | User Mgmt | none | Opens "Create User" dialog | |
| I02 | **Create** (dialog) | Create User | name+email+pass+role+dept | POST user, invalidate, success | |
| I03 | **Create** (empty) | Create User | missing fields | Error "All fields are required" | |
| I04 | **Cancel** (dialog) | Create User | none | Dialog closes | |
| I05 | Pull-to-refresh | User Mgmt | swipe | Invalidates provider | |

### 8.2 Profile (`profile_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| I06 | **Logout** icon | Profile AppBar | none | Clears auth, back to Login | |
| I07 | **Change Password** | Profile | none | Opens "Change Password" dialog | |
| I08 | **Update** (dialog) | Change Password | old+new pass | PUT password, success snackbar | |
| I09 | **Update** (short) | Change Password | <8 char new | Error "at least 8 characters" | |
| I10 | **Cancel** (dialog) | Change Password | none | Dialog closes | |
| I11 | Ghost Mode display | Profile | none | Shows Active/Inactive based on PIN used | |

---

## 9. LOGISTICS MODULE

### 9.1 Logistics Hub (`logistics_hub_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| L01 | **Orders** tile (admin) | Logistics Hub | none | Push LogisticsOrdersScreen | |
| L02 | **Vendors** tile | Logistics Hub | none | Push VendorsListScreen | |
| L03 | **My Dispatches** tile | Logistics Hub | none | Push MyDispatchesScreen | |
| L04 | **Log Dispatch** tile | Logistics Hub | none | Push DispatchRecordingScreen | |

### 9.2 Vendors (`vendors_list_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| L05 | **+ FAB** | Vendors | none | Opens "Add Vendor" dialog | |
| L06 | **Add** (dialog) | Add Vendor | name+contact+phone+email+mode | POST vendor, refresh, success | |
| L07 | **Add** (invalid) | Add Vendor | bad phone/email | Validation errors | |
| L08 | **Cancel** (dialog) | Add Vendor | none | Dialog closes | |
| L09 | Payment mode dropdown | Add Vendor | select | GhostModeAware wraps dropdown | |

### 9.3 Orders (`logistics_orders_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| L10 | **ExpansionTile** | Orders | tap | Expands to show action buttons | |
| L11 | **Assign Manager** | Order actions | tap | Opens assign dialog with user list | |
| L12 | **Assign** (dialog) | Assign Manager | select manager | PUT assign, invalidate | |
| L13 | **Create PO** | Order actions | tap | Opens PO dialog | |
| L14 | **Create PO** (dialog) | Create PO | vendorId+amount+date | POST PO, invalidate, success | |
| L15 | **Schedule Dispatch** | Order actions | tap | Opens dispatch dialog | |
| L16 | **Schedule** (dialog) | Create Dispatch | staff+responsibility+driver+vehicle | POST dispatch, invalidate, success | |
| L17 | Pull-to-refresh | Orders | swipe | Invalidates provider | |

### 9.4 My Dispatches (`my_dispatches_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| L18 | **Log Dispatch** | Dispatch card | dispatch ID | POST event type=dispatch, success | |
| L19 | **Log Delivery** | Dispatch card | dispatch ID | POST event type=delivery, success | |
| L20 | Pull-to-refresh | My Dispatches | swipe | Invalidates provider | |

### 9.5 Dispatch Recording (`dispatch_recording_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| L21 | **Dispatch Logged** | Dispatch Recording | dispatchId + notes + challanUrl | POST event type=dispatch, success | |
| L22 | **Delivery Logged** | Dispatch Recording | dispatchId + notes + challanUrl | POST event type=delivery, success | |
| L23 | **Dispatch Logged** (no ID) | Dispatch Recording | blank ID | Error "Enter a valid Dispatch ID" | |

---

## 10. EXECUTION MODULE

### 10.1 Execution Hub (`execution_hub_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| E01 | **All/My Jobs** tile | Execution Hub | none | Push ExecutionJobsScreen | |
| E02 | **Installers** tile | Execution Hub | none | Push InstallersListScreen | |
| E03 | **Site Updates** tile | Execution Hub | none | Push SiteUpdatesScreen | |
| E04 | **Client Sign-off** tile | Execution Hub | none | Push ClientSignoffScreen | |

### 10.2 Jobs List (`execution_jobs_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| E05 | **Job row** tap | Jobs List | job ID | Navigates to JobDetailScreen | |
| E06 | Pull-to-refresh | Jobs List | swipe | Invalidates provider | |

### 10.3 Job Detail (`job_detail_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| E07 | **Site Updates** chip | Job Detail | none | Push SiteUpdatesScreen(jobId) | |
| E08 | **Sign-off** chip | Job Detail | none | Push ClientSignoffScreen(jobId) | |
| E09 | **Assign Installer** chip | Job Detail | none | Opens assign dialog | |
| E10 | **Assign** (dialog) | Assign Installer | installerId+price+date | POST assign, success | |
| E11 | **Assign** (invalid) | Assign Installer | bad input | Error "Invalid input" | |
| E12 | **Check In** chip | Job Detail | none | POST contractor check-in, success | |
| E13 | **Check Out** chip | Job Detail | none | POST contractor check-out, success | |
| E14 | **Record Payment** chip | Job Detail | none | Opens payment dialog | |
| E15 | **Record** (payment) | Payment dialog | amount+ref+type+mode | POST payment, reload | |
| E16 | **Cash** payment mode | Payment dialog | select cash | GhostModeAware wraps amount field | |
| E17 | Pull-to-refresh | Job Detail | swipe | Reloads updates + ledger | |

### 10.4 Installers (`installers_list_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| E18 | **+ FAB** | Installers | none | Opens "Add Installer" dialog | |
| E19 | **Add** (dialog) | Add Installer | name+phone+expertise+rate | POST installer, refresh, success | |
| E20 | **Add** (invalid) | Add Installer | bad phone/rate | Validation errors | |
| E21 | **Filter chips** | Installers | tap | Filters by expertise area | |
| E22 | Rate field | Add Installer | none | GhostModeAware wraps rate input | |

### 10.5 Site Updates (`site_updates_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| E23 | **+ FAB** | Site Updates | none | Opens "Create Site Update" dialog | |
| E24 | **Capture photo** | Update dialog | tap | Opens image picker | |
| E25 | **Remove photo** | Update dialog | tap | Clears selected photo | |
| E26 | **Create** (dialog) | Update dialog | jobId+description+photo | POST update, refresh, success | |
| E27 | **Create** (empty) | Update dialog | missing fields | Validation errors | |

### 10.6 Client Sign-off (`client_signoff_screen.dart`)

| # | Button | Page | Input | Expected Output | Actual Output |
|---|--------|------|-------|-----------------|---------------|
| E28 | **Signature canvas** | Client Sign-off | draw | Captures signature URL | |
| E29 | **Status dropdown** | Client Sign-off | select | client_approved or redo_required | |
| E30 | **Submit Sign-off** | Client Sign-off | jobId+sig+status+feedback | POST signoff, success | |
| E31 | **Submit** (no sig) | Client Sign-off | missing signature | Error "Please capture client signature" | |
| E32 | **Submit** (no jobId) | Client Sign-off | blank job ID | Error "Job ID is required" | |

---

## CROSS-CUTTING CONCERNS

| # | Area | Test | Expected | Actual |
|---|------|------|----------|--------|
| X01 | **GhostMode** | Cash quotation without HS PIN | Field hidden/disabled | |
| X02 | **GhostMode** | Cash quotation WITH HS PIN | Field visible and editable | |
| X03 | **GhostMode** | Cash payment in execution | Amount field wrapped in GhostModeAware | |
| X04 | **GhostMode** | Vendor payment mode (cash) | Dropdown wrapped in GhostModeAware | |
| X05 | **GhostMode** | Installer rate field | Wrapped in GhostModeAware | |
| X06 | **GhostMode** | Expense amount field | Wrapped in GhostModeAware | |
| X07 | **Offline** | Load screens without network | Cached data shown from local DB | |
| X08 | **Offline** | Create lead offline | Queued or error shown | |
| X09 | **Role gate** | Staff sees admin-only tiles | Orders tile hidden in Logistics Hub | |
| X10 | **Role gate** | Staff sees "Home" not "Team" | Nav label changes based on role | |
| X11 | **Role gate** | Leave Admin / Expense Ledger | Only visible for admin roles | |
| X12 | **Role gate** | User Management tile | Only for super_admin/admin | |
| X13 | **SyncBanner** | Network status | Banner shows when offline | |

---

## END-TO-END FLOWS

### Flow 1: Lead to Order
1. Login (A01) -> PIN (A13) -> CRM tab (N02) -> Create Lead (C03/C04) -> View Lead (C02) -> Update status through pipeline (C08) -> Create Quotation (C12/C16) -> Approve Quotation (C18) -> **Verify**: Order auto-created in Logistics (L10)

### Flow 2: Order to Delivery
1. Logistics tab (N03) -> Orders (L01) -> Assign Manager (L11/L12) -> Create PO (L13/L14) -> Schedule Dispatch (L15/L16) -> My Dispatches (L03) -> Log Dispatch (L18) -> Log Delivery (L19)

### Flow 3: Installation to Sign-off
1. Execution tab (N04) -> Jobs (E01) -> Job Detail (E05) -> Assign Installer (E09/E10) -> Check In (E12) -> Site Update (E07/E26) -> Check Out (E13) -> Record Payment (E14/E15) -> Sign-off (E08/E30)

### Flow 4: HR Daily Cycle (Staff)
1. Home (N01) -> Check-In (S02) -> Work day -> Check-Out (S03) -> My Attendance (S08/H01)

### Flow 5: Leave Request Cycle
1. More (N05) -> My Leaves (M02) -> Create Leave (H05/H08) -> Admin: Leave Admin (M07) -> Approve/Reject (H19/H20) -> Employee: Cancel (H10)

### Flow 6: Expense Cycle
1. More (N05) -> My Expenses (M03) -> Create Expense (H12/H14) -> Admin: Expense Ledger (M08/H23)

### Flow 7: Override Request
1. Staff Home -> Off-site link (S04) -> Pick times (S05/S06) -> Submit (S07) -> Admin Dashboard -> Pending tab (D04) -> Approve/Reject (D08/D09)
