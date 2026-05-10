# Module 1: Identity & Access Management (IAM)

## 1. Pages & Routes
| Page / Route | Description |
| :--- | :--- |
| `/login` | Standard Email/Password login screen. |
| `/pin-setup` | Forced screen for Super Admin first login to set Normal & High-Security PINs. |
| `/pin-verify` | Daily entry screen. The PIN entered here dictates `ghost_mode` access. |
| `/users` | Admin dashboard displaying all system users. |
| `/profile` | Current user profile details. |

## 2. Modals & UI Components
- **CreateUserModal:** Form with Name, Email, Password, Role dropdown, and Department dropdown.
- **ChangePasswordModal:** Form for updating the user's own password.

## 3. Backend API Mapping
- `POST /api/v1/login` ➔ Validates credentials. Returns initial JWT.
- `POST /api/v1/iam/verify-pin` ➔ Validates PIN. Returns final JWT (with `ghost_mode` flag).
- `POST /api/v1/iam/setup-pins` ➔ Submits Normal and High-Security PINs (Super Admin only).
- `GET /api/v1/users` ➔ Populates the user list table.
- `POST /api/v1/users` ➔ Form submission from `CreateUserModal`.
- `PATCH /api/v1/users/me/password` ➔ Form submission from `ChangePasswordModal`.

## 4. Local Caching & Sync
- **No SQLite Caching required.**
- **Secure Storage:** The final JWT is stored securely. The App Shell reads this token on startup to determine if it should route to `/pin-verify` or `/login`.