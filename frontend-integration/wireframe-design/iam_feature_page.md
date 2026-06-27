# IAM Feature Wireframes

## 1. Login Page (`/login`)
**Layout:** Centered card on a branded background (desktop) or full screen (mobile).
**Components:**
- **App Logo:** Centered at the top.
- **Input Text:** "Email Address" (with email validation icon).
- **Input Text:** "Password" (with toggle visibility eye icon).
- **Button:** "Login" (Primary color, full width, shows loading spinner on `POST /api/v1/login`).
- **Text Link:** "Forgot Password?".

## 2. PIN Setup Page (`/pin-setup`)
*Forced for Super Admin on first login.*
**Layout:** Stepper or vertical form inside a secure-looking card.
**Components:**
- **Typography:** "System Initialization: Set Security PINs".
- **Input Number (Masked):** "Enter Normal PIN" (4-6 digits).
- **Input Number (Masked):** "Confirm Normal PIN".
- **Divider:** "High-Security Area".
- **Input Number (Masked):** "Enter High-Security PIN (Ghost Mode)".
- **Input Number (Masked):** "Confirm High-Security PIN".
- **Helper Text:** Red warning text if Normal PIN matches High-Security PIN.
- **Button:** "Save & Initialize" (`POST /api/v1/iam/setup-pins`).

## 3. PIN Verify Page (`/pin-verify`)
**Layout:** Minimalist numpad interface (like a mobile lock screen).
**Components:**
- **Avatar:** Shows logged-in user's profile picture or initials.
- **Typography:** "Enter PIN to access CRM".
- **PIN Dots:** 4-6 empty circles that fill as the user types.
- **Custom Numpad Widget:** Buttons 0-9, Clear, and Fingerprint/FaceID icon (if bio-auth enabled).
- **Hidden Logic:** `POST /api/v1/iam/verify-pin` triggers automatically when length is reached.

## 4. Users Dashboard Page (`/users`)
**Layout:** Standard Admin Scaffold (Sidebar + Main Content).
**Components:**
- **App Bar:** Title "User Management", Search Input.
- **Action Button:** "Create New User" (Floating Action Button on mobile, top right button on desktop).
- **Data Table / ListView:** Columns for Name, Email, Role, Department, Status (Active/Inactive toggle).
- **Pagination Controls:** Bottom of the table.

## 5. Modals
### Create User Modal
- **Dialog Box:** "Add New System User".
- **Input Text:** Full Name.
- **Input Text:** Email Address.
- **Input Text:** Temporary Password.
- **Dropdown:** Role Selection (Super Admin, Admin, Staff).
- **Dropdown:** Department Selection (Management, Operations, HR, Sales).
- **Buttons:** "Cancel" (Secondary) and "Create" (Primary - `POST /api/v1/users`).

### Change Password Modal
- **Dialog Box:** "Update Password".
- **Input Text:** Old Password.
- **Input Text:** New Password.
- **Buttons:** "Close" and "Update" (`PATCH /api/v1/users/me/password`).