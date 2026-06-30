# UI PAGE 2: The Command Center (Workspace)

This page unifies the "Staff Home" and "Admin Dashboard" into a single, cohesive interface for day-to-step operations and management.

## 🖥️ Visual Structure (CLI Mockup)

```text
==========================================================================================
 📂 PIPELINE | ⚡ WORKSPACE | 👤 PROFILE                             [ Date: Oct 24, 2026 ]
==========================================================================================
 
 [ QUICK ACTIONS ]
 +------------------+   +------------------+   +------------------+
 |   ( ) Clock In   |   |   + Request      |   |   $ Claim        |
 |   Status: OFF    |   |     Leave        |   |     Expense      |
 +------------------+   +------------------+   +------------------+

 -----------------------------------------------------------------------------------------
 [ MANAGER INBOX (Action Required) ] (Visible to Admins only)
 
 ! Leave Request: John Doe (Sick, 2 days)              [Approve] [Reject]
 ! Expense Claim: Jane Smith ($450, Travel)            [Approve] [Reject]
 ! Quote Approval: Client Echo ($1,200)                [Approve] [Reject]

 -----------------------------------------------------------------------------------------
 [ MY TIMELINE ]
 
 09:00 AM - You Clocked In
 Yesterday - Expense Claim ($45) Approved by Admin
 2 Days Ago - Leave Request (Vacation) Approved by Admin

==========================================================================================
```

---

## 🔌 API Mapping

### ✅ NEW APIs Added (Reads)
* `GET /api/v1/workspace/action-items` - Fetches the unified Manager Inbox (aggregates pending leaves, pending expenses, and pending quotes).
* `GET /api/v1/workspace/personal-timeline` - Fetches the unified personal history (combines attendance logs and personal HR request statuses).

### ♻️ EXISTING APIs Preserved (Writes/Mutations)
The UI action buttons continue to fire directly to the existing endpoints. 
* `POST /api/v1/hr/clock-in` (Clock in action)
* `POST /api/v1/hr/clock-out` (Clock out action)
* `POST /api/v1/hr/leave` (Submit a leave request)
* `POST /api/v1/hr/expense` (Submit an expense claim)
* `PUT /api/v1/hr/leave/{id}/approve` (Manager approves leave)
* `PUT /api/v1/hr/expense/{id}/approve` (Manager approves expense)

### ❌ UNUSED APIs (For the Frontend)
* `GET /api/v1/hr/pending-leaves` (Replaced by action-items fetch)
* `GET /api/v1/hr/pending-expenses` (Replaced by action-items fetch)
* `GET /api/v1/hr/attendance/history` (Replaced by personal-timeline fetch)
