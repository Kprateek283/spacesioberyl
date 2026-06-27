# Execution Jobs Dashboard Wireframe

## Layout: Tabbed Dashboard
**Components:**
- **Page Header:** "Site Installations".
- **Tabs:** "Active Sites" | "Completed Sites".
- **Job Cards:**
  - Order ID, Client Address, Tech Manager Name.
  - Progress Indicator: "Procurement Complete -> Site Prep -> Installation -> Signoff".
  - Status Badge: `pending_contractor`, `in_progress`, `client_approved`.
- **Admin Action:** "Create Installation" (Creates job from a delivered Logistics Order).
- **Card Tap Action:** Navigates to `ExecutionSiteDetailsScreen` (where the signoff and check-ins happen).