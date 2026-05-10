# Logistics Feature Wireframes

## 1. Orders Dashboard Page (`/logistics/orders`)
**Layout:** Data Table (Desktop) or expanding List Cards (Mobile).
**Components:**
- **List Items:** Order ID, Linked Quotation amount, Status (Procurement, Ready, Dispatched).
- **Assignee Dropdown:** To set `operations_manager_id` (`PATCH /logistics/orders/:id/assign`).
- **Expandable Row Content:** Shows "Create Purchase Order" button and "Schedule Dispatch" button.

## 2. Vendors Directory Page (`/logistics/vendors`)
**Layout:** Searchable Contact List.
*Crucial Offline Feature: Reads entirely from SQLite cache.*
**Components:**
- **Search Bar:** "Search vendor name or material..."
- **List Tile:** Company Name, Contact Person, Phone.
- **Trailing Action:** Phone icon (opens native dialer).
- **FAB:** "Add Vendor".

## 3. My Dispatches / Field Ops Page (`/logistics/dispatches`)
**Layout:** Large, touch-friendly task cards built for field use (high visibility, high contrast).
**Components:**
- **Task Card:** Shows Delivery Address, Transport Driver Info, Vehicle No.
- **Massive Swipe Button 1 (Blue):** "Swipe to Log Dispatch (Left Warehouse)".
  - Triggers `PATCH /logistics/dispatches/:id/log` (type: dispatch).
- **Massive Swipe Button 2 (Green):** "Swipe to Log Delivery (Arrived at Site)".
  - Triggers the same API (type: delivery).
  - Opens `ChallanUploadModal` if delivery challan photo is required.
- **Offline Indicator:** If internet is down, swipe button turns Orange and text changes to "Saved Offline. Will sync automatically."

## 4. Modals

### Create Purchase Order (PO) Modal
- **Dropdown:** Select Vendor (Populated from SQLite/API).
- **Input Number:** Total Amount.
- **Date Picker Calendar:** Expected Delivery Date.
- **Button:** "Issue PO" (`POST /logistics/orders/:id/pos`).

### Schedule Dispatch Modal
- **Dropdown:** Loading Responsibility (Company, Vendor, Client).
- **Input Text:** Driver Name.
- **Input Text:** Vehicle Number.
- **Input Phone:** Driver Phone.
- **Button:** "Create Dispatch Plan" (`POST /logistics/dispatches`).

### Challan Upload Modal (Post-Delivery)
- **Image Capture Component:** "Take Photo of Signed Delivery Challan".
- **Input TextArea:** Notes (e.g., "Items damaged in transit").
- **Button:** "Submit".