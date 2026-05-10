# Execution Feature Wireframes

## 1. Jobs Dashboard Page (`/execution/jobs` & `/execution/my-sites`)
**Layout:** Tabbed interface (Active Sites vs. Completed).
**Components:**
- **Site Cards:** Shows Order ID, Assigned Tech Manager, Assigned Contractor, Status, Estimated Completion Date.
- **Action Button:** "View Site Details".
- **Admin Only Button:** "Create Installation" (`POST /execution/orders/:id/installation`) - converts a delivered order into an active job.

## 2. Site Details Page (`/execution/jobs/:id`)
**Layout:** Multi-section scrollable view (Mobile first).
**Components:**
- **Header Section:** Site location, technical manager, `installer_job_status` badge.
- **Contractor Section:**
  - Name and Agreed Price.
  - **Action Button:** "Assign Installer" (if none assigned).
  - **Check-in/Out Buttons:** "Log Contractor Arrival" / "Log Departure".
- **Timeline / Updates Section:**
  - Vertical list of photos and notes submitted via `/updates/sync`.
  - **FAB:** "Add Site Update" (Camera icon).
- **Financial / Ledger Section:**
  - Progress bar showing Paid vs. Remaining Balance.
  - **Action Button:** "Record Payment" (Opens payment modal).
- **Final Signoff Section:**
  - If status != client_approved, show huge "Get Client Signoff" button.

## 3. Contractor Management Page (`/execution/contractors`)
**Layout:** Standard List View (Offline cached via SQLite).
**Components:**
- **Search Bar:** "Search carpenters, plumbers..."
- **List Tile:** Name, Expertise Area, Standard Rate.
- **Trailing Action:** Call button.
- **FAB:** "Add Contractor".

## 4. Modals & Complex UI Components

### Assign Installer Modal
- **Dropdown:** Select Installer.
- **Input Number:** Agreed Job Price (₹).
- **Date Picker Calendar:** Estimated Completion.
- **Button:** "Assign" (`PATCH /execution/jobs/:id/assign`).

### Contractor Check-In/Out Modal (Manual Verification)
- **Dialog Box:** "Verify Contractor Presence".
- **Input TextArea:** Verification Notes (Required: e.g., "Spoke on phone, confirmed reached site").
- **Image Picker (Optional):** Upload proof photo (WhatsApp screenshot).
- **Button:** "Log Check-In" (`POST /execution/contractors/jobs/:id/check-in`).

### Record Payment Modal (Accounts/Admin)
- **Dropdown:** Payment Type (Advance, Final Discharge).
- **Input Number:** Amount.
- **Dropdown:** Payment Mode (Bank Transfer, Cash, UPI). *(Cash is hidden if `ghost_mode` false).*
- **Input Text:** Transaction Reference.
- **Helper Text (Dynamic):** If Final Discharge is selected, and `installations.status` is not `client_approved`, show bold red error text and disable the Submit button.
- **Button:** "Record Payment" (`POST /execution/contractors/jobs/:id/payments`).

### Add Site Update Modal (Offline First)
- **Image Capture Area:** Huge box to tap and open Camera. Shows thumbnail once captured.
- **Input TextArea:** "What work was completed today?"
- **Hidden Input:** Timestamp (captured automatically when modal opens).
- **Button:** "Save Update". (Saves to SQLite immediately. Sync Manager uploads to MinIO and hits `/updates/sync` in background).

### Client Signoff Canvas (The Financial Lock)
**Layout:** Landscape orientation forced (Mobile/Tablet).
**Components:**
- **Header Text:** "I hereby approve the installation works completed at this site."
- **Drawing Canvas (`SignaturePad`):** Large blank white area capturing touch/stylus input.
- **Clear Button:** "Erase Signature".
- **Submit Button:** "Accept & Approve".
  - *Logic:* Converts canvas to PNG -> Uploads to MinIO -> Gets URL -> Submits `PATCH /execution/jobs/:id/signoff`.