# Module 3: CRM & Sales Pipeline

## 1. Pages & Routes
| Page / Route | Description |
| :--- | :--- |
| `/crm/leads` | Primary Sales Dashboard. Kanban board dragging leads through the state machine. |
| `/crm/leads/:id` | Detailed Lead View. Shows Lead Info, Follow-up Timeline, and Quotations. |
| `/crm/support` | Client Complaints dashboard for post-sale support. |

## 2. Modals & UI Components
- **AddLeadModal:** Client Name, Phone, Email, Source.
- **ScheduleFollowUpModal:** Date/Time picker and Notes.
- **CompleteFollowUpModal:** Forces input of `outcome_notes` before clearing the task.
- **CreateQuotationForm:** A complex dynamic form allowing adding/removing Line Items (Name, Qty, Price) and selecting Payment Terms.
- **QuotationPDFViewer:** Integrates a Flutter PDF viewing widget to display the URL returned from MinIO.
- **AddComplaintModal:** Title, Description, Priority, and associated Lead/Order ID.

## 3. Backend API Mapping
- **Leads:**
  - `GET /api/v1/crm/leads` ➔ Populates Kanban board.
  - `POST /api/v1/crm/leads` ➔ Creates new lead.
  - `PATCH /api/v1/crm/leads/:id/status` ➔ Triggered when a lead card is dragged to a new column.
- **Follow-ups:**
  - `GET /api/v1/crm/followups/my-queue` ➔ Renders the "My Tasks" sidebar for sales reps.
  - `PATCH /api/v1/crm/followups/:id/complete` ➔ Submits the `CompleteFollowUpModal`.
- **Quotations:**
  - `POST /api/v1/crm/leads/:id/quotations` ➔ Submits the dynamic `CreateQuotationForm`.
  - `PATCH /api/v1/crm/quotations/:id/status` ➔ "Approve Quote" button. (This invisibly moves the project to Logistics).
- **Complaints:**
  - `POST /api/v1/crm/complaints` ➔ Submits `AddComplaintModal`.

## 4. Local Caching & Sync
- **Soft Caching:** Fetch and store active leads in SQLite to allow Sales Reps to view client contact numbers even in dead zones. Read-only offline mode for this module.