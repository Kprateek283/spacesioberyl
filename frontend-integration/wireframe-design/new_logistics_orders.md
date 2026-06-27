# Logistics Orders Dashboard Wireframe

## Layout: Expandable List / Table
**Components:**
- **Page Header:** "Pending Procurement".
- **List Items (Orders):**
  - Shows Order ID, Linked Quotation Amount, CRM Handoff Date.
  - Badge: "Pending PO", "Partially Ordered", "Ready for Dispatch".
- **Expandable Action Area:**
  - When tapped, the row expands to show actions:
  - "Create Purchase Order" (Opens PO Modal).
  - "Schedule Dispatch" (Opens Dispatch Modal).
- **Integration:** `GET /api/v1/logistics/orders`.