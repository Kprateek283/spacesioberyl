# UI PAGE 3: Profile & Settings (Auth Module)

This page handles all session management, security configurations, and user profile information. Since the Auth module is already fairly robust, this mainly serves as a clean wrapper to access those existing features without cluttering the main navigation.

## 🖥️ Visual Structure (CLI Mockup)

```text
==========================================================================================
 📂 PIPELINE | ⚡ WORKSPACE | 👤 PROFILE                          
==========================================================================================
 
 [ USER IDENTITY ]
 +---------------------------------------------------------------------------------------+
 |  [Avatar]   Name: Admin User                                                          |
 |             Email: admin@gmail.com                                                    |
 |             Role: Administrator                                                       |
 +---------------------------------------------------------------------------------------+

 -----------------------------------------------------------------------------------------
 [ SECURITY & ACCESS ]
 
 > Reset Standard PIN                              [ Configure ]
 > Change High-Security PIN (Ghost Mode)           [ Configure ]
 > Reset Password                                  [ Send Link ]

 -----------------------------------------------------------------------------------------
 [ SESSION ]
 
 [ Logout (Clear Local Data) ]

==========================================================================================
```

---

## 🔌 API Mapping

### ✅ NEW APIs Added (Reads)
* *None required.* The Auth and Profile flows are perfectly serviced by the existing identity endpoints.

### ♻️ EXISTING APIs Preserved (Reads/Writes)
The UI forms on this page and the initial login screens map directly to these existing endpoints.
* `POST /api/v1/login` (Initial session generation)
* `POST /api/v1/iam/setup-pin` (Configuring the Standard & Ghost PINs)
* `POST /api/v1/iam/verify-pin` (Unlocking the session)
* `POST /api/v1/password/forgot` (Requesting the OTP for password reset)
* `POST /api/v1/password/reset` (Submitting the OTP + New Password)

### ❌ UNUSED APIs (For the Frontend)
* *None.* All existing Auth/IAM endpoints remain actively utilized.
