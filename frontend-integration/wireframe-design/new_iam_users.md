# IAM Users Dashboard Wireframe

## Layout: Data Table / List
**Components:**
- **Page Header:** "User Management".
- **Action Button:** "Create New User" (Floating Action Button on mobile, top right button on desktop).
- **Search Bar:** Filter users by name or email.
- **Data Table / List View:**
  - Columns: Name, Email, Role (Badge), Department, Status.
  - Row Actions: "Edit Role", "Deactivate".
- **Integration:** 
  - `GET /api/v1/users` to populate.
  - Clicking "Create New User" opens the `CreateUserModal` designed in `iam_feature_page.md`.