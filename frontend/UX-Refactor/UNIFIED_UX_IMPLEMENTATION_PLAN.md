# Unified UX Implementation Plan

**Objective:** Consolidate the disjointed modules (CRM, Logistics, Execution, HR, Admin) into a seamless, unified 3-tab architecture without deleting any existing underlying APIs. 

---

## 1. Backend Architecture Plan (BFF Pattern)
**Philosophy:** Do not delete or heavily mutate existing microservice-style APIs. Instead, implement a **Backend-for-Frontend (BFF)** pattern by introducing new "Aggregation APIs". This allows the frontend to fetch unified data in a single network call, reducing latency and simplifying state management.

### A. New Aggregation APIs to Add
1. **`GET /api/v1/projects/pipeline`**
   - **Purpose:** Powers the unified Kanban board.
   - **Behavior:** This endpoint queries the `leads`, `orders` (logistics), and `jobs` (execution) tables. It maps these distinct database entities into a single, unified `ProjectCard` DTO.
   - **Response Structure:** Returns a list of projects categorized by their lifecycle stage: `[ { stage: 'LEAD', data: {...} }, { stage: 'PROCUREMENT', data: {...} }, { stage: 'EXECUTION', data: {...} } ]`.
   - **Benefit:** The frontend no longer has to manage three separate parallel HTTP streams and merge them locally.

2. **`GET /api/v1/projects/{id}/details`**
   - **Purpose:** Powers the unified Project Side-Panel.
   - **Behavior:** Accepts a Lead ID (which acts as the master Project ID). It fetches the Lead details, its associated Quotations, the linked Logistics Order (and POs), and the linked Execution Job (and site updates).
   - **Response Structure:** A massive, deeply nested JSON object containing the complete 360-degree view of the project's history across all departments.

3. **`GET /api/v1/workspace/action-items`**
   - **Purpose:** Powers the "Action Required" inbox for managers in the Command Center.
   - **Behavior:** Queries pending CRM Quotations, pending HR Leave Requests, and pending HR Expense Claims.
   - **Response Structure:** Returns a unified stream of actionable items sorted by urgency.

4. **`GET /api/v1/workspace/personal-timeline`**
   - **Purpose:** Powers the "My Timeline" section for all users in the Command Center.
   - **Behavior:** Aggregates a user's recent clock-in/out attendance logs, their personal leave request statuses, and their personal expense claim statuses.
   - **Response Structure:** Returns a chronological list of `TimelineEvent` objects.

5. **`POST` & `GET /api/v1/projects/{id}/docs`**
   - **Purpose:** Handles external document and media uploads for a project lifecycle.
   - **Behavior:** `POST` accepts `multipart/form-data` to upload files (signed contracts, vendor invoices, site photos) to S3/local storage. `GET` retrieves the list of attached files.
   - **Response Structure:** Returns a list of `ProjectDocument` objects with file URLs and metadata.

### B. Existing APIs
- **Keep all existing mutation APIs intact:** `/api/v1/leads`, `/api/v1/logistics/orders/{id}/vendor`, `/api/v1/hr/clock-in`, etc. The unified frontend UI will simply route button clicks to these existing, proven endpoints.

---

## 2. Frontend Implementation Plan
**Philosophy:** Radically simplify the navigation and UI hierarchy. Shift from a "module-based" mental model to a "task-based" mental model.

### A. Navigation & Routing Overhaul
Replace the current 5-item Bottom Navigation Bar/Sidebar with just 3 items:
1. **Pipeline** (Route: `/pipeline`) - Replaces CRM, Logistics, and Execution lists.
2. **Command Center** (Route: `/workspace`) - Replaces Staff Home and Admin Dashboard.
3. **Profile & Settings** (Route: `/profile`) - Replaces Security Setup, Logout, and Auth config.

### B. UI/UX Restructuring

**1. The Pipeline Screen (Kanban Board)**
- **Component:** A horizontally scrollable Kanban board using `flutter_staggered_grid_view` or custom PageViews.
- **Columns:** 
  - *Active Leads* (from CRM)
  - *Awaiting Procurement* (from Logistics)
  - *Active Installations* (from Execution)
- **Interaction (The Project Drawer):** Clicking any card opens a modal bottom sheet (mobile) or a slide-out right drawer (desktop/tablet). This drawer contains tabbed views:
  - **Info:** CRM quotes, client details.
  - **Logistics:** Vendors, POs.
  - **Site Updates:** Contractor check-ins.
  - **Documents & Media:** A gallery/list for uploading signed contracts, vendor invoices, and site photos (integrates with device camera for offline-first uploads).
  All actions (Approve Quote, Issue PO, Assign Contractor) live contextually inside this drawer.

**2. The Command Center Screen (Unified Workspace)**
- **Top Section (Personal Quick Actions):** Big, premium glass-morphic buttons for `Clock In/Out`, `Request Leave`, and `Claim Expense`.
- **Middle Section (Manager Inbox):** (Only visible if `user.role == admin`). A unified list of pending approvals (Leaves, Expenses, Quotes). Each row has quick-action `Approve` / `Reject` buttons.
- **Bottom Section (Personal Timeline):** A vertical timeline (using `timeline_tile` package) showing the user's recent check-ins, approved leaves, and reimbursed expenses.

### C. State Management (Riverpod) Refactor
- Deprecate the siloed state providers (`crmProvider`, `logisticsProvider`, `executionProvider`) for view rendering.
- Create a new `pipelineProvider` that listens to the unified `GET /api/v1/projects/pipeline` API.
- Create a new `workspaceProvider` that manages the local state for the Command Center.
- **Offline Sync:** The `SyncService` architecture remains **completely untouched**. Since the frontend will still fire mutations to the exact same endpoints (e.g., `POST /api/v1/hr/clock-in`), the local SQLite `outbox_queue` will seamlessly continue to intercept and background-sync these actions.
