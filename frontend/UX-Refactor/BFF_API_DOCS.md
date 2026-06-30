# Backend-For-Frontend (BFF) API Documentation

This document outlines the 5 new unified endpoints created to support the Unified UX (Pipeline, Command Center, and Profile screens).

The BFF layer aggregates data concurrently from the underlying CRM, Logistics, and Execution domains, so the frontend only needs to make a single API call per page.

---

## 1. The Pipeline Kanban Board
**Endpoint:** `GET /api/v1/projects/pipeline`

**Description:** Returns a lightweight summary of all projects categorized into their current highest stage (Lead, Procurement, Execution, Completed).

**Response:**
```json
{
  "leads": [
    {
      "id": 1,
      "client_name": "QA Lead",
      "status": "Lead - first_call",
      "value": 0,
      "last_updated": "2026-06-27T21:40:50Z"
    }
  ],
  "procurement": [ ... ],
  "execution": [ ... ],
  "completed": [ ... ]
}
```

---

## 2. Project Details (360-Degree Drawer)
**Endpoint:** `GET /api/v1/projects/{id}/details`

**Description:** A massive payload containing everything related to a specific project. Fetches from 7 different tables concurrently.

**Response:**
```json
{
  "lead": { ... },           // CRM Lead object
  "quotes": [ ... ],         // Array of CRM Quotation objects
  "order": { ... },          // Logistics Order object (if it exists)
  "pos": [ ... ],            // Array of Purchase Orders (if any)
  "job": { ... },            // Execution Installation object (if any)
  "site_updates": [ ... ],   // Array of Site Updates logs
  "documents": [ ... ]       // Array of uploaded documents
}
```

---

## 3. Upload Project Document
**Endpoint:** `POST /api/v1/projects/{id}/docs`

**Description:** Uploads a document (PDF, Image, etc.) directly to MinIO storage and logs it in the database.

**Payload:** `multipart/form-data`
- `file`: (Required) The physical file to upload (Max 10 MB).
- `document_type`: (Optional) String representing the document type (e.g., "contract", "invoice", "other"). Defaults to "other".

**Response:** Returns the created `ProjectDocument` object with the public `file_url`.

---

## 4. Manager Action Items Inbox
**Endpoint:** `GET /api/v1/workspace/action-items`

**Description:** Fetches an aggregated list of tasks that require the current logged-in user's attention (e.g., new assigned leads).

**Response:**
```json
{
  "items": [
    {
      "id": "lead-25",
      "type": "LEAD_ASSIGNMENT",
      "title": "New Lead: Test Client",
      "requested_by": "System",
      "amount": 0,
      "created_at": "2026-06-30T10:00:00Z"
    }
  ]
}
```

---

## 5. Personal Timeline
**Endpoint:** `GET /api/v1/workspace/personal-timeline`

**Description:** Returns a chronological feed of events triggered by the user (e.g., generating quotes).

**Response:**
```json
{
  "events": [
    {
      "id": "quote-12",
      "event_type": "QUOTE_UPDATE",
      "description": "Quotation #12 (Total: $590.00) status is client_approved",
      "timestamp": "2026-06-30T09:01:02Z"
    }
  ]
}
```
