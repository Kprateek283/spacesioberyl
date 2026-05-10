# Module 5: Field Execution & Installation

## 1. Pages & Routes
| Page / Route | Description | Role Access |
| :--- | :--- | :--- |
| `/execution/jobs` | Dashboard of all active site installations. | Tech Admin |
| `/execution/my-sites` | Focused view for Tech Managers showing their assigned sites. | Tech Staff |
| `/execution/contractors`| Directory of external installers/carpenters. | Tech / Ops |
| `/execution/jobs/:id` | Site Details. Includes Timeline, Contractor Check-Ins, Payments, and Signoff. | Tech Staff |

## 2. Modals & UI Components
- **AssignContractorModal:** Select Installer from dropdown, input Negotiated Price & Target Date.
- **ContractorCheckInModal:** Requires internal manager to input `verification_notes` (e.g., "Called at 9AM").
- **RecordPaymentModal:** For Accounts. Amount, Payment Type (Advance/Discharge), Reference.
- **AddSiteUpdateModal:** Offline-ready form. Captures Text Notes and opens Camera for Site Photo.
- **ClientSignoffView:** Full-screen canvas (`SignaturePad` widget). Client physically signs the screen.

## 3. Backend API Mapping
- **Contractors & Jobs:**
  - `GET /api/v1/execution/installers` ➔ Populates directory.
  - `PATCH /api/v1/execution/jobs/:id/assign` ➔ Submits `AssignContractorModal`.
  - `POST /api/v1/execution/contractors/jobs/:id/check-in` ➔ Submits `ContractorCheckInModal`.
  - `POST /api/v1/execution/contractors/jobs/:id/payments` ➔ Submits `RecordPaymentModal`.
- **Site Updates (The Sync Engine):**
  - `POST /api/v1/execution/jobs/:id/updates/sync` ➔ Accepts the bulk array of offline logs.
- **Financial Lock:**
  - `PATCH /api/v1/execution/jobs/:id/signoff` ➔ Triggered when the `SignaturePad` is saved. The app must first upload the PNG to MinIO (via an S3 presigned URL or direct API), get the URL, and submit it here.

## 4. Local Caching & Sync (CRITICAL)
- **Installer Directory SQLite Sync:** Similar to Vendors, cache `/installers` for offline phone calls.
- **My Sites Cache:** The `/my-tasks` JSON response is cached in SQLite so the Tech Manager can open the site details without network.
- **Site Updates Sync Queue:** 
  1. User takes a photo and writes notes in `AddSiteUpdateModal`.
  2. Saved to local SQLite: `installation_updates(local_id, job_id, notes, photo_path, timestamp)`.
  3. When network is restored:
     - Iterate queue.
     - Upload `photo_path` files to MinIO.
     - Build JSON payload.
     - POST to `/updates/sync`.
     - Delete local queue entries on 200 OK.