# UI PAGE 1: The Unified Pipeline

This page acts as the master Kanban board, replacing the disjointed lists in the CRM, Logistics, and Execution tabs.

## 🖥️ Visual Structure (CLI Mockup)

```text
==========================================================================================
 📂 PIPELINE | ⚡ WORKSPACE | 👤 PROFILE                            [+ New Lead (API: POST)]
==========================================================================================
 
 [  LEADS (CRM)  ]   [ PROCUREMENT (Logistics) ]   [ EXECUTION (Install) ]   [ COMPLETED ]
 
 +---------------+   +-------------------------+   +---------------------+   +-----------+
 | Client: Alpha |   | Order: Beta             |   | Job: Gamma          |   | Delta     |
 | Status: Hot   |   | Vendor: Awaiting        |   | Contractor: Joe     |   | Status:   |
 | Quote: --     |   | PO: --                  |   | On-site: Yes        |   | Signed Off|
 +---------------+   +-------------------------+   +---------------------+   +-----------+
         |                       |                            |
         v                       v                            v
 +---------------+   +-------------------------+   +---------------------+   
 | Client: Echo  |   | Order: Foxtrot          |   | Job: Hotel          |   
 | Status: Cold  |   | Vendor: Acme Inc        |   | Contractor: Unassign|   
 | Quote: Sent   |   | PO: Issued              |   | On-site: No         |   
 +---------------+   +-------------------------+   +---------------------+   

==========================================================================================
```

### 👉 Project Drawer (When a card is clicked)
```text
 +---------------------------------------------------------------------------------------+
 | [X] Close Drawer                                                                      |
 |                                                                                       |
 | PROJECT: Client Alpha            Status: Lead -> Quote -> [Procurement] -> Execution  |
 | ------------------------------------------------------------------------------------- |
 | [CRM Data]        | [Logistics Data]          | [Execution Data] | [ 📎 DOCUMENTS ]   |
 | Quotes: $500      | Assigned Vendor: None     | Site Updates:    | 1 Contract PDF     |
 | Status: Approved  |                           | None             | 2 Site Photos      |
 |                                                                                       |
 |                       [ BUTTON: Assign Vendor (API: PUT) ]                            |
 |                       [ BUTTON: Upload Photo (API: POST) ]                            |
 +---------------------------------------------------------------------------------------+
```

---

## 🔌 API Mapping

### ✅ NEW APIs Added
These replace the fragmented list fetches and introduce external document handling.
* `GET /api/v1/projects/pipeline` - Fetches the initial board state (all columns).
* `GET /api/v1/projects/{id}/details` - Fetches the massive consolidated payload for the Project Drawer.
* `POST` & `GET /api/v1/projects/{id}/docs` - Handles uploading and fetching external project files/photos.

### ♻️ EXISTING APIs Preserved (Writes/Mutations)
The UI buttons inside the Drawer still map directly to these existing endpoints.
* `POST /api/v1/leads` (Create Lead)
* `PUT /api/v1/leads/{id}/status` (Update CRM status)
* `POST /api/v1/crm/quotes` (Create Quote)
* `PUT /api/v1/crm/quotes/{id}/approve` (Approve Quote)
* `PUT /api/v1/logistics/orders/{id}/vendor` (Assign Logistics Vendor)
* `POST /api/v1/logistics/orders/{id}/po` (Issue PO)
* `PUT /api/v1/execution/jobs/{id}/contractor` (Assign Contractor)

### ❌ UNUSED APIs (For the Frontend)
The frontend will no longer call these directly to render lists (though they may remain on the backend for other microservices).
* `GET /api/v1/leads` (Replaced by the Pipeline board fetch)
* `GET /api/v1/logistics/orders` (Replaced by the Pipeline board fetch)
* `GET /api/v1/execution/jobs` (Replaced by the Pipeline board fetch)
