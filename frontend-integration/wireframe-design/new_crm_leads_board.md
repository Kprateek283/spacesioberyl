# CRM Leads Board Wireframe

## Layout: Horizontal Kanban Board
**Components:**
- **Page Header:** "Sales Pipeline".
- **Action Button:** "Add Lead" -> Opens Add Lead Modal.
- **Kanban Columns:** (Scrollable horizontally)
  - New
  - Contacted
  - Quote Sent
  - Negotiation
  - Finalized
- **Kanban Cards:** 
  - Client Name, Priority Badge (Hot, Warm, Cold), Assigned Rep Avatar.
  - *Interaction:* Long-press and drag to move between columns. Dropping fires `PATCH /crm/leads/:id/status`.
  - *Interaction:* Tap card to navigate to `CrmLeadDetailsScreen`.