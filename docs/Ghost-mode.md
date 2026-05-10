This document outlines the architecture, setup flow, and enforcement logic for the "Ghost Mode" dual-PIN functionality, specifically designed for the Super Admin of the **Spacesio Beryl CRM**.

---

# Feature Blueprint: Super Admin "Ghost Mode"

### 1. Overview & Objective
"Ghost Mode" provides a critical layer of financial security. It enforces data-level cloaking of sensitive financial transactions—specifically **Cash-based Quotations and Orders**—at the database level. 

To access this sensitive data, the Super Admin must log in using a specific High-Security PIN. If logged in with the Standard PIN, the CRM functions normally, but completely cloaks the existence of cash transactions. To any user without the High-Security JWT claim, this data simply does not exist.

### 2. Implementation: Mandatory Dual-PIN Setup (First Login)

Because this feature dictates data visibility, the setup of both PINs is **mandatory** for the Super Admin role during their very first system initialization or login.

#### The Setup Workflow

1.  **Detection:** Upon successful email/password authentication of the Super Admin, the backend detects that PIN hashes are missing.
2.  **Initialization Redirect:** The Flutter UI redirects the Super Admin to a specialized **Ghost Mode Initialization Screen**.
3.  **Mandatory Input:** The screen forces the input of two distinct PINs:
    *   `Field 1:` Enter New Normal PIN (for standard day-to-day access).
    *   `Field 2:` Confirm Normal PIN.
    *   `Field 3:` Enter High-Security PIN (to unlock cash data).
    *   `Field 4:` Confirm High-Security PIN.
4.  **Validation Rules:**
    *   All standard PIN constraints must be met (e.g., 4 or 6 digits, no simple sequences).
    *   Normal PIN *must* match Confirm Normal PIN.
    *   High-Security PIN *must* match Confirm High-Security PIN.
    *   **CRITICAL RULE:** The raw value of the **Normal PIN *cannot equal* the High-Security PIN.** The UI must block submission and show an error if they match.
5.  **Secure Submission:** When valid and different, the Flutter app submits both raw PINs to the Go backend.
6.  **Backend Hashing:** The backend validates again that they are not identical, hashes them, and updates the database record.

### 3. Architecture: Database Schema Updates (IAM Module)

We need to add a dedicated column to store the hashed High-Security PIN for the Super Admin role.

```sql
-- Apply to your Super Admin database instance
ALTER TABLE users 
ADD COLUMN high_security_pin_hash VARCHAR(255) NULL;

-- Example seed logic for the initial Super Admin record (assuming ID 1)
-- UPDATE users SET high_security_pin_hash = NULL WHERE id = 1; 
```

### 4. Architecture: Authentication Logic (Go Backend)

The standard `POST /api/v1/iam/verify-pin` endpoint must be updated to handle the "fork in the road."

```go
// Inside your PIN verification handler
func VerifyPin(c *gin.Context) {
    var req models.PinVerificationRequest
    // ... bind and validate req

    // Fetch user from DB based on context/token
    user := db.GetUserById(c.GetUserId())

    // 1. Fork in the road: Check Standard PIN first
    if utils.CompareHashAndPin(user.PinHash, req.RawPin) {
        // Success: This is a standard login.
        token, _ := iam.GenerateJWT(user.ID, user.Role, false) // 3rd arg: ghost_mode=false
        c.JSON(200, gin.H{"token": token, "ghost_mode": false})
        return
    }

    // 2. Fork in the road: Check High-Security PIN
    // (Only applies to users where high_security_pin_hash is not NULL)
    if user.HighSecurityPinHash != nil && 
       utils.CompareHashAndPin(*user.HighSecurityPinHash, req.RawPin) {
        // Success: This is a GHOST MODE login.
        token, _ := iam.GenerateJWT(user.ID, user.Role, true) // 3rd arg: ghost_mode=true
        c.JSON(200, gin.H{"token": token, "ghost_mode": true})
        return
    }

    // 3. Neither PIN matched
    c.JSON(401, gin.H{"error": "Invalid PIN"})
}
```

### 5. Architecture: The Effect - Data Access Filtering

The `ghost_mode` boolean claim in the JWT token dictates what the SQL database is allowed to return. This filtering applies to both **quotations** and **orders**.

First, update the `quotations` table to include `cash` as a valid payment term.

```sql
-- Update your quotation types
ALTER TABLE quotations 
DROP CONSTRAINT IF EXISTS check_payment_type; -- if you had one

ALTER TABLE quotations 
ADD CONSTRAINT check_payment_type 
CHECK (payment_term_type IN ('100_advance', 'advance_and_post_install', 'custom_credit', 'po_based', 'cash'));
```

Next, implement a middleware interceptor in Go to rewrite incoming queries for financial lists.

```go
// Pseudo-code for a database middleware/repository method
func (repo *QuotationRepository) ListQuotations(ctx *gin.Context) ([]models.Quotation, error) {
    // Extract Ghost Mode status from JWT claim (placed in context by AuthMiddleware)
    isGhostMode := ctx.GetBool("ghost_mode")
    
    baseQuery := "SELECT * FROM quotations"
    
    // ENFORCEMENT LOOP
    if !isGhostMode {
        // Automatically cloak cash transactions.
        // This is applied for all users, AND Super Admin using standard PIN.
        baseQuery += " WHERE payment_term_type != 'cash'"
    }
    
    // ... Execute baseQuery and return results
}
```

**Final System Behavior:**

| Logged-In User | PIN Used | JWT Claim | Visual Effect on Quotations/Orders |
| :--- | :--- | :--- | :--- |
| Any Staff/Admin | Standard PIN | `ghostMode: false` | All cash transactions are invisible. |
| **Super Admin** | **Standard PIN** | `ghostMode: false` | **All cash transactions are invisible.** |
| **Super Admin** | **High-Security PIN**| `ghostMode: true` | **All transactions (including cash) are visible.** |
