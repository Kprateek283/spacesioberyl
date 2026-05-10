# Module 4: Supply Chain & Logistics

## 1. Pages & Routes
| Page / Route | Description | Role Access |
| :--- | :--- | :--- |
| `/logistics/orders` | Core Ops Dashboard. List of active projects transitioned from CRM. | Ops / Admin |
| `/logistics/vendors` | Directory of suppliers and raw material providers. | All Staff |
| `/logistics/dispatches`| "My Tasks" view for Ops staff managing physical loading and delivery. | Ops Staff |

## 2. Modals & UI Components
- **AddVendorModal:** Company Name, Phone, Payment Mode, etc.
- **CreatePOModal:** Select Vendor (Dropdown), Total Amount, Target Date.
- **ScheduleDispatchModal:** Select Driver, Vehicle No, Loading Responsibility.
- **LogTimestampButton:** A massive swipe-to-confirm button for logging "Dispatched" and "Delivered" events in the field.

## 3. Backend API Mapping
- **Orders & POs:**
  - `GET /api/v1/logistics/orders` ➔ Renders the main active project list.
  - `POST /api/v1/logistics/orders/:id/pos` ➔ Submits `CreatePOModal`.
- **Vendors:**
  - `GET /api/v1/logistics/vendors` ➔ Populates the directory and dropdowns.
- **Dispatch Tracking:**
  - `GET /api/v1/logistics/dispatches/my-tasks` ➔ Loads assigned trucks/deliveries.
  - `PATCH /api/v1/logistics/dispatches/:id/log` ➔ Triggered by the `LogTimestampButton`.

## 4. Local Caching & Sync (CRITICAL)
- **Vendor Directory SQLite Sync:** The app must download the entire `/vendors` list into SQLite. Ops staff in deep warehouses need to be able to open the app, search a vendor, and call them without internet.
- **Dispatch Timestamp Queue:** If Ops staff swipes the "Delivered" button but has no internet:
  1. Save `{ dispatchId, type: 'delivery', time: current_device_time, status: 'pending_sync' }` to SQLite.
  2. Update UI instantly to show "Delivered (Offline)".
  3. Sync Manager pushes to `PATCH /logistics/dispatches/:id/log` when 4G returns.