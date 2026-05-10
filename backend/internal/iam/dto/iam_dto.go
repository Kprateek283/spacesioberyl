package dto

// ---------------------------------------------------------
// OUTGOING RESPONSES (What the Flutter App receives)
// ---------------------------------------------------------

// UserResponse is the safe version of the User model (No password hash!)
type UserResponse struct {
	ID         int    `json:"id"`
	Name       string `json:"name"`
	Email      string `json:"email"`
	Role       string `json:"role"`
	Department string `json:"department"`
	IsActive   bool   `json:"is_active"`
}

// AuthResponse is returned on successful Login or Token Refresh
type AuthResponse struct {
	AccessToken     string        `json:"access_token"`
	RefreshToken    string        `json:"refresh_token"`
	User            *UserResponse `json:"user,omitempty"`             // Included on login, omitted on refresh
	RequiresPinSetup bool         `json:"requires_pin_setup,omitempty"` // True if Super Admin hasn't set up PINs yet
}

// PinAuthResponse is returned after successful PIN verification
type PinAuthResponse struct {
	AccessToken string `json:"access_token"`
	GhostMode   bool   `json:"ghost_mode"`
}

// BasicResponse is used for simple success/error messages
type BasicResponse struct {
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}

// ---------------------------------------------------------
// INCOMING REQUESTS (What the Flutter App sends)
// ---------------------------------------------------------

// LoginRequest defines the expected JSON for /api/v1/login
type LoginRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

type ForgotPasswordRequest struct {
	Email string `json:"email" validate:"required,email"`
}

type ResetPasswordRequest struct {
	Email       string `json:"email" validate:"required,email"`
	OTP         string `json:"otp" validate:"required"`
	NewPassword string `json:"new_password" validate:"required,min=8"`
}

type ChangePasswordRequest struct {
	OldPassword string `json:"old_password" validate:"required"`
	NewPassword string `json:"new_password" validate:"required,min=8"`
}

// CreateUserRequest is used by Admins/SuperAdmins to make new accounts
type CreateUserRequest struct {
	Name       string `json:"name" validate:"required"`
	Email      string `json:"email" validate:"required,email"`
	Password   string `json:"password" validate:"required,min=8"`
	Role       string `json:"role" validate:"required"`
	Department string `json:"department" validate:"required"`
}

// UpdateStatusRequest is for soft deactivations.
// We use a pointer to bool (*bool) so we can detect if the frontend
// omitted the field entirely vs. sending "false".
type UpdateStatusRequest struct {
	IsActive *bool `json:"is_active" validate:"required"`
}

// ---------------------------------------------------------
// GHOST MODE: PIN Setup & Verification
// ---------------------------------------------------------

// SetupPinsRequest is used by the Super Admin to initialize their dual PINs.
// Normal PIN must be exactly 4 digits.
// High-Security PIN must be exactly 6 digits.
type SetupPinsRequest struct {
	NormalPin        string `json:"normal_pin" validate:"required"`
	ConfirmNormalPin string `json:"confirm_normal_pin" validate:"required"`
	HighSecurityPin  string `json:"high_security_pin" validate:"required"`
	ConfirmHighSecPin string `json:"confirm_high_security_pin" validate:"required"`
}

// VerifyPinRequest is used for the PIN verification step after login
type VerifyPinRequest struct {
	Pin string `json:"pin" validate:"required"`
}
