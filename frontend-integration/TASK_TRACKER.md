# Frontend Finalization Task Tracker

## Task 1: Frontend Navigation & State Management
- [x] Add navigation and state management dependencies (`go_router`, `flutter_riverpod`).
- [x] Implement robust routing (e.g., `go_router`) to handle protected routes and 401 redirects.
- [x] Build `MainLayoutScreen` (Shell routing, Sidebar/Bottom Navigation).
- [x] Implement State Management (e.g., `provider` or `riverpod`).
- [x] Decode JWT on boot to extract `ghost_mode` and Role claims.
- [x] Implement UI masking logic (hide "Cash" options globally if `ghost_mode` == false).

## Task 2: Remaining Screen Implementations
*(Several HTML designs were duplicates, so these will be built from the `new_` wireframe specs).*
- [x] `CrmLeadsBoardScreen`: Drag-and-drop Kanban board for sales pipeline.
- [x] `LogisticsOrdersScreen`: Dashboard for Ops to view approved CRM quotes.
- [x] `LogisticsVendorsScreen`: Offline-first directory reading from SQLite.
- [x] `ExecutionJobsScreen`: Dashboard for Tech Managers to view active installations.
- [x] `ExecutionContractorsScreen`: Offline-first installer directory.
- [x] `IamUsersScreen`: Admin table for user management and creation.

## Task 3: MinIO File Upload Integrations
- [x] `ClientSignoffScreen`: Integrate `signature` package, capture PNG, and upload to MinIO before hitting the Signoff API.
- [x] `AddSiteUpdateModal`: Integrate `image_picker` for offline-first photo capture.
- [x] `LogExpenseModal`: Integrate `image_picker` for receipt capture.
- [x] Implement generic MinIO upload service in `ApiClient`.

## Task 4: Background Worker UI Feedback
- [x] Implement pull-to-refresh (`RefreshIndicator`) on major dashboards (Leads, Orders, Jobs).
- [x] Add visual indicators (badges or snackbars) when a background task completes (e.g., Quote approved -> Order appears).
- [x] Ensure SQLite sync manager triggers UI rebuilds when offline items successfully flush to the backend.