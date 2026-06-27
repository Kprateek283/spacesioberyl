# CRM Feature Wireframes

## 1. Leads Board Page (`/crm/leads`)
**Layout:** Horizontal scrolling Kanban Board.
**Components:**
- **Columns:** New, First Call, PDF Sent, Sample Sent, Site Visit, Negotiation, Finalized.
- **Lead Cards:** Client Name, Phone, Source Badge. Drag-and-drop capability.
- **Drag Action:** Dropping a card updates status via `PATCH /crm/leads/:id/status`. If dropped in a hidden "Lost" zone, it opens the `MarkLostModal`.
- **Top App Bar Button:** "Add Lead".

## 2. Lead Details Page (`/crm/leads/:id`)
**Layout:** Two-column split (Desktop) or Tabbed View (Mobile).
**Components:**
- **Profile Header:** Name, Contact Buttons (Direct call/WhatsApp intent icons), Assignee Dropdown (`PATCH /crm/leads/:id/assign`).
- **Tab 1: Timeline & Follow-ups**
  - Vertical Timeline Widget.
  - "Schedule Follow-up" Button.
  - Pending Task Card with "Mark Complete" checkbox.
- **Tab 2: Quotations**
  - List of past quotes (Status: Draft, Sent, Approved).
  - "Create New Quote" Button.
- **Tab 3: Complaints**
  - List of linked complaints.

## 3. Quotation Generator Page / Form
**Layout:** Full-screen complex form.
**Components:**
- **Header:** "Generate Quotation for [Client Name]".
- **Section: Line Items (Dynamic List)**
  - Rows containing: Input Text (Item Name), Input Number (Qty), Input Number (Unit Price).
  - "Add Item" Button (appends a new row).
  - Running Total Text (updates dynamically `Qty * Price`).
- **Section: Taxation**
  - Input Number: Tax Rate (%).
- **Section: Payment Terms**
  - Dropdown: 100% Advance, Advance + Post-Install, Custom, Cash. *(Cash option is completely hidden if the JWT `ghost_mode` claim is false).*
- **Section: Manual Override (Escape Hatch)**
  - File Upload Widget: "Upload Custom PDF instead of generating".
- **Buttons:** "Preview" and "Generate & Save" (`POST /crm/leads/:id/quotations`).

## 4. Quotation PDF Viewer
**Layout:** Full screen modal or dedicated page.
**Components:**
- **PDF Render Widget:** Displays the MinIO PDF URL.
- **Action Bar (Bottom):**
  - "Mark as Sent".
  - "Client Approved" (Huge green button, triggers `PATCH /crm/quotations/:id/status`, warning text: *This will push the order to Logistics*).
  - "Reject".

## 5. Modals

### Add Lead Modal
- **Input Text:** Client Name.
- **Input Phone:** Phone Number.
- **Input Email:** Email Address.
- **Dropdown:** Source (Website, Referral, Walk-in).

### Schedule Follow-up Modal
- **Date/Time Picker:** "Select Date & Time".
- **Input TextArea:** Notes / Agenda.
- **Button:** "Schedule" (`POST /crm/followups`).

### Complete Follow-up Modal
- **Input TextArea:** Outcome Notes (Required).
- **Button:** "Mark Done" (`PATCH /crm/followups/:id/complete`).

### Mark Lost Modal
- **Input TextArea:** Reason for losing the lead (Required).
- **Button:** "Confirm Loss".