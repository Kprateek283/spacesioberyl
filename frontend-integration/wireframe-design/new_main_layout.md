# Main Layout Screen Wireframe

## Layout: App Shell / Navigation Shell
**Mobile View:** Bottom Navigation Bar + Top App Bar.
**Desktop/Tablet View:** Permanent Left Navigation Rail / Drawer + Top App Bar.

## Components
- **Top App Bar:**
  - Leading: Hamburger menu (mobile only) or Logo (desktop).
  - Title: Dynamic based on the current nested route (e.g., "HR Dashboard").
  - Trailing Actions: Sync Status Banner (Offline/Online), Notifications Icon, Profile Avatar.

- **Navigation Items (Sidebar / Bottom Nav):**
  - Home / HR (Module 2)
  - CRM (Module 3)
  - Logistics (Module 4)
  - Execution (Module 5)
  - IAM / Admin (Module 1 - conditionally visible based on RBAC).

- **Global Sync Banner:**
  - A subtle `AnimatedContainer` that slides down from the App Bar if `SyncService` is actively flushing the `outbox_queue`. Shows "Syncing X items..."

- **Content Area:**
  - Renders the child route provided by the Router.