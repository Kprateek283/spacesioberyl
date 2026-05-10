# Module 2: Internal HR & Administration

## 1. Pages & Routes
| Page / Route | Description | Role Access |
| :--- | :--- | :--- |
| `/hr/dashboard` | Main HR hub. Shows active check-in status, quick actions. | All Users |
| `/hr/attendance` | Company-wide attendance list and override requests. | Admin / Super Admin |
| `/hr/leaves` | Global leave tracker (Kanban or List view of Pending/Approved). | Admin / Super Admin |
| `/hr/my-leaves` | User's personal leave history and request button. | All Users |
| `/hr/expenses` | Daily ledger of office expenses. | Admin / Accounts |

## 2. Modals & UI Components
- **CheckInOverrideModal:** Pops up if the API rejects standard Check-In (not on office Wi-Fi). Prompts for `override_reason`.
- **RequestLeaveModal:** Form with Leave Type, Start Date, End Date, and Reason.
- **AdminProcessLeaveModal:** Modal for Admins to view leave details, input `admin_remarks`, and click Approve or Reject.
- **LogExpenseModal:** Form for Amount, Person Paid, Context, Date, and Receipt Photo upload.

## 3. Backend API Mapping
- **Attendance:**
  - `POST /api/v1/hr/attendance/check-in` ➔ Tied to the massive "Check In" button.
  - `POST /api/v1/hr/attendance/check-out` ➔ Tied to "Check Out" button.
  - `GET /api/v1/hr/attendance` & `/overrides` ➔ Populates Admin tables.
  - `PATCH /api/v1/hr/attendance/overrides/:id` ➔ Admin approval/rejection.
- **Leaves:**
  - `POST /api/v1/hr/leaves` ➔ `RequestLeaveModal` submission.
  - `GET /api/v1/hr/leaves` ➔ Populates Admin Leave board.
  - `PATCH /api/v1/hr/leaves/:id/status` ➔ Admin approval logic.
- **Expenses:**
  - `POST /api/v1/hr/expenses` ➔ `LogExpenseModal` submission.

## 4. Local Caching & Sync
- Mostly online module.
- If a user loses internet right at checkout, the app can store the `checkOutTime` locally in SQLite and push the `/check-out` API call automatically when connectivity is restored.