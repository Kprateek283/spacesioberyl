package service

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"regexp"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/spacesioberyl/system-v1/internal/cache"
	"github.com/spacesioberyl/system-v1/internal/iam/dto"
	"github.com/spacesioberyl/system-v1/internal/iam/model"
)

// Per-account brute-force protection (backend-bugs #4). This is the second
// layer above the per-IP httprate limiter; it protects a single account from a
// distributed attempt that rotates source IPs — critical for the 4/6-digit PINs.
const (
	maxLoginAttempts = 5
	loginLockWindow  = 15 * time.Minute
	maxPinAttempts   = 5
	pinLockWindow    = 15 * time.Minute
	maxOTPAttempts   = 5
)

// dummyHash is a valid bcrypt hash compared against on the user-not-found login
// path so both branches pay the same bcrypt cost, closing the timing side
// channel (backend-bugs #24). Its plaintext is irrelevant — it never matches.
const dummyHash = "$2a$10$LUbTYMGgUj7BnN7Y9uCil.OtJ94YVyDzMqF3ZcZyijc2x50seGIcm"

// UserRepository defines the exact database functions this service requires
type UserRepository interface {
	GetUserByEmail(ctx context.Context, email string) (*model.User, error)
	CreateUser(ctx context.Context, user *model.User) (int, error)
	GetRoleIDByName(ctx context.Context, roleName string) (int, error)
	UpdateUserStatus(ctx context.Context, userID int, isActive bool) error
	GetUserByID(ctx context.Context, id int) (*model.User, error)
	ListUsers(ctx context.Context) ([]*model.User, error)
	UpdatePassword(ctx context.Context, userID int, newHash string) error
	SetupPins(ctx context.Context, userID int, pinHash, highSecPinHash string) error

	// Refresh-token lifecycle (backend-bugs #7/#8)
	InsertRefreshToken(ctx context.Context, userID int, jti string, ghostMode bool, expiresAt time.Time) error
	GetRefreshTokenByJTI(ctx context.Context, jti string) (*model.RefreshToken, error)
	RevokeRefreshToken(ctx context.Context, jti string) error
	RevokeAllUserRefreshTokens(ctx context.Context, userID int) error
}

type IAMService struct {
	repo      UserRepository
	jwtSecret string
	appEnv    string
}

func NewIAMService(repo UserRepository, secret, appEnv string) *IAMService {
	return &IAMService{
		repo:      repo,
		jwtSecret: secret,
		appEnv:    appEnv,
	}
}

// isLockedOut reports whether the failure counter at key has reached max. It
// fails open on a Redis error: the per-IP httprate limiter remains as a floor,
// and locking every account out because the cache blipped is the worse outcome.
func (s *IAMService) isLockedOut(ctx context.Context, key string, max int64) bool {
	n, err := cache.Client.Get(ctx, key).Int64()
	if err != nil {
		return false
	}
	return n >= max
}

// recordFailure increments the failure counter at key, (re)setting its window on
// the first failure.
func (s *IAMService) recordFailure(ctx context.Context, key string, window time.Duration) {
	n, err := cache.Client.Incr(ctx, key).Result()
	if err == nil && n == 1 {
		_ = cache.Client.Expire(ctx, key, window).Err()
	}
}

// clearFailures drops the counter after a success.
func (s *IAMService) clearFailures(ctx context.Context, key string) {
	_ = cache.Client.Del(ctx, key).Err()
}

// Login handles the core authentication flow
func (s *IAMService) Login(ctx context.Context, req dto.LoginRequest) (*dto.AuthResponse, error) {
	// 0. Per-account lockout: block a targeted account once it has accumulated
	// too many recent failures, regardless of source IP (backend-bugs #4).
	failKey := "login_fail:" + strings.ToLower(req.Email)
	if s.isLockedOut(ctx, failKey, maxLoginAttempts) {
		return nil, errors.New("too many failed attempts, please try again later")
	}

	// 1. Fetch user by email
	user, err := s.repo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		// Equalize timing with the found-user path so a missing email cannot be
		// distinguished by response time (backend-bugs #24).
		_ = CheckPasswordHash(req.Password, dummyHash)
		s.recordFailure(ctx, failKey, loginLockWindow)
		return nil, errors.New("invalid credentials")
	}

	// 2. Check if they have been soft-deactivated
	if !user.IsActive {
		return nil, errors.New("account is deactivated")
	}

	// 3. Compare passwords
	if !CheckPasswordHash(req.Password, user.PasswordHash) {
		s.recordFailure(ctx, failKey, loginLockWindow)
		return nil, errors.New("invalid credentials")
	}
	s.clearFailures(ctx, failKey)

	// 4. Generate Tokens and persist the refresh token server-side so it can be
	// rotated and revoked (backend-bugs #7/#8).
	accessToken, refreshToken, refreshJTI, err := GenerateTokens(user, s.jwtSecret)
	if err != nil {
		return nil, errors.New("failed to generate tokens")
	}
	if err := s.repo.InsertRefreshToken(ctx, user.ID, refreshJTI, false, time.Now().Add(RefreshTokenTTL)); err != nil {
		return nil, errors.New("failed to persist session")
	}

	// 5. Ghost Mode detection: If Super Admin and PINs are not set up yet, flag it
	requiresPinSetup := false
	if user.RoleName == model.RoleSuperAdmin && user.PinHash == nil {
		requiresPinSetup = true
	}

	// 6. Construct the safe DTO response
	return &dto.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		RequiresPinSetup: requiresPinSetup,
		User: &dto.UserResponse{
			ID:         user.ID,
			Name:       user.Name,
			Email:      user.Email,
			Role:       string(user.RoleName),
			Department: string(user.Department),
			IsActive:   user.IsActive,
		},
	}, nil
}

// SetupPins handles the mandatory first-time PIN initialization for the Super Admin
func (s *IAMService) SetupPins(ctx context.Context, userID int, req dto.SetupPinsRequest) error {
	// 1. Validate that the user is actually a Super Admin
	user, err := s.repo.GetUserByID(ctx, userID)
	if err != nil {
		return errors.New("user not found")
	}
	if user.RoleName != model.RoleSuperAdmin {
		return errors.New("only super_admin can set up ghost mode PINs")
	}

	// 2. Validate PIN confirmations match
	if req.NormalPin != req.ConfirmNormalPin {
		return errors.New("normal PIN and confirmation do not match")
	}
	if req.HighSecurityPin != req.ConfirmHighSecPin {
		return errors.New("high-security PIN and confirmation do not match")
	}

	// 3. Validate PIN formats: Normal PIN = exactly 4 digits, High-Security PIN = exactly 6 digits
	if matched, _ := regexp.MatchString(`^\d{4}$`, req.NormalPin); !matched {
		return errors.New("normal PIN must be exactly 4 digits")
	}
	if matched, _ := regexp.MatchString(`^\d{6}$`, req.HighSecurityPin); !matched {
		return errors.New("high-security PIN must be exactly 6 digits")
	}

	// 4. CRITICAL: The two PINs cannot be the same value
	if req.NormalPin == req.HighSecurityPin {
		return errors.New("normal PIN and high-security PIN cannot be identical")
	}

	// 5. Hash both PINs
	normalHash, err := HashPassword(req.NormalPin)
	if err != nil {
		return errors.New("failed to secure normal PIN")
	}
	highSecHash, err := HashPassword(req.HighSecurityPin)
	if err != nil {
		return errors.New("failed to secure high-security PIN")
	}

	// 6. Persist
	return s.repo.SetupPins(ctx, userID, normalHash, highSecHash)
}

// VerifyPin authenticates a PIN and determines Ghost Mode state.
// Returns the access token and whether ghost_mode is active.
func (s *IAMService) VerifyPin(ctx context.Context, userID int, pin string) (*dto.PinAuthResponse, error) {
	user, err := s.repo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, errors.New("user not found")
	}

	if !user.IsActive {
		return nil, errors.New("account is deactivated")
	}

	// PINs must be set up before verification
	if user.PinHash == nil {
		return nil, errors.New("PINs have not been set up. Please call setup-pins first")
	}

	// Per-account PIN lockout. The high-security PIN mints ghost-mode tokens, so
	// the 4/6-digit space must not be brute-forceable (backend-bugs #4).
	failKey := fmt.Sprintf("pin_fail:%d", userID)
	if s.isLockedOut(ctx, failKey, maxPinAttempts) {
		return nil, errors.New("too many failed attempts, please try again later")
	}

	// Fork 1: Check Standard PIN → ghost_mode=false
	if CheckPasswordHash(pin, *user.PinHash) {
		accessToken, _, _, err := GenerateTokens(user, s.jwtSecret)
		if err != nil {
			return nil, errors.New("failed to generate token")
		}
		s.clearFailures(ctx, failKey)
		return &dto.PinAuthResponse{
			AccessToken: accessToken,
			GhostMode:   false,
		}, nil
	}

	// Fork 2: Check High-Security PIN → ghost_mode=true
	if user.HighSecurityPinHash != nil && CheckPasswordHash(pin, *user.HighSecurityPinHash) {
		accessToken, _, _, err := GenerateGhostModeTokens(user, s.jwtSecret)
		if err != nil {
			return nil, errors.New("failed to generate token")
		}
		s.clearFailures(ctx, failKey)
		return &dto.PinAuthResponse{
			AccessToken: accessToken,
			GhostMode:   true,
		}, nil
	}

	// Fork 3: Neither PIN matched
	s.recordFailure(ctx, failKey, pinLockWindow)
	return nil, errors.New("invalid PIN")
}

// CreateUser handles hashing the password before saving to the DB
func (s *IAMService) CreateUser(ctx context.Context, req dto.CreateUserRequest, roleID int) (int, error) {
	hashedPassword, err := HashPassword(req.Password)
	if err != nil {
		return 0, errors.New("failed to hash password")
	}

	user := &model.User{
		Name:         req.Name,
		Email:        req.Email,
		PasswordHash: hashedPassword,
		RoleID:       roleID,
		Department:   model.Department(req.Department),
		IsActive:     true,
	}

	return s.repo.CreateUser(ctx, user)
}

// GetRoleID fetches the ID for a role string (used during user creation)
func (s *IAMService) GetRoleID(ctx context.Context, roleName string) (int, error) {
	return s.repo.GetRoleIDByName(ctx, roleName)
}

// UpdateStatus toggles a user's active state
func (s *IAMService) UpdateStatus(ctx context.Context, userID int, isActive bool) error {
	return s.repo.UpdateUserStatus(ctx, userID, isActive)
}

// GetUserByID fetches a specific user and maps it to a safe DTO
func (s *IAMService) GetUserByID(ctx context.Context, id int) (*dto.UserResponse, error) {
	user, err := s.repo.GetUserByID(ctx, id)
	if err != nil {
		return nil, err
	}

	return &dto.UserResponse{
		ID:         user.ID,
		Name:       user.Name,
		Email:      user.Email,
		Role:       string(user.RoleName),
		Department: string(user.Department),
		IsActive:   user.IsActive,
	}, nil
}

// ListUsers fetches all users and maps them to safe DTOs
func (s *IAMService) ListUsers(ctx context.Context) ([]*dto.UserResponse, error) {
	users, err := s.repo.ListUsers(ctx)
	if err != nil {
		return nil, err
	}

	var response []*dto.UserResponse
	for _, u := range users {
		response = append(response, &dto.UserResponse{
			ID:         u.ID,
			Name:       u.Name,
			Email:      u.Email,
			Role:       string(u.RoleName),
			Department: string(u.Department),
			IsActive:   u.IsActive,
		})
	}
	return response, nil
}

// RefreshToken validates a 30-day token against its server-side record, rotates
// it, and mints a fresh pair. Presenting a token whose row is already revoked is
// treated as theft: the whole family is revoked (backend-bugs #7/#8).
func (s *IAMService) RefreshToken(ctx context.Context, refreshToken string) (*dto.AuthResponse, error) {
	// 1. Parse and validate the JWT signature/expiry
	claims := &TokenClaims{}
	token, err := jwt.ParseWithClaims(refreshToken, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(s.jwtSecret), nil
	})

	if err != nil || !token.Valid || claims.TokenType != "refresh" {
		return nil, errors.New("invalid or expired refresh token")
	}

	// 2. Look the token up server-side. No jti (a pre-migration token) or no row
	// (unknown/pruned) means it cannot be trusted for rotation.
	if claims.ID == "" {
		return nil, errors.New("invalid or expired refresh token")
	}
	stored, err := s.repo.GetRefreshTokenByJTI(ctx, claims.ID)
	if err != nil {
		return nil, errors.New("invalid or expired refresh token")
	}

	// 3. Reuse detection: a revoked row presented again means this token was
	// already rotated or logged out. Assume theft and revoke every session.
	if stored.RevokedAt != nil {
		_ = s.repo.RevokeAllUserRefreshTokens(ctx, stored.UserID)
		return nil, errors.New("refresh token reuse detected; all sessions have been revoked, please log in again")
	}

	// 4. Fetch the user to embed their most up-to-date role/department, and to
	// confirm they were not deactivated while offline.
	user, err := s.repo.GetUserByID(ctx, stored.UserID)
	if err != nil {
		return nil, errors.New("user no longer exists")
	}
	if !user.IsActive {
		return nil, errors.New("account is deactivated")
	}

	// 5. Rotate: mint a new pair (ghost mode is taken from the stored row, the
	// canonical record), revoke the presented token, and persist the new one.
	var newAccessToken, newRefreshToken, newJTI string
	if stored.GhostMode {
		newAccessToken, newRefreshToken, newJTI, err = GenerateGhostModeTokens(user, s.jwtSecret)
	} else {
		newAccessToken, newRefreshToken, newJTI, err = GenerateTokens(user, s.jwtSecret)
	}
	if err != nil {
		return nil, errors.New("failed to generate new tokens")
	}

	if err := s.repo.RevokeRefreshToken(ctx, stored.JTI); err != nil {
		return nil, errors.New("failed to rotate session")
	}
	if err := s.repo.InsertRefreshToken(ctx, user.ID, newJTI, stored.GhostMode, time.Now().Add(RefreshTokenTTL)); err != nil {
		return nil, errors.New("failed to persist session")
	}

	return &dto.AuthResponse{
		AccessToken:  newAccessToken,
		RefreshToken: newRefreshToken,
		// Notice we omit the full User object here to keep the payload lightweight
	}, nil
}

// Logout blacklists the active access token and revokes every refresh token for
// the user, so the session cannot be resurrected via /refresh (backend-bugs #7).
func (s *IAMService) Logout(ctx context.Context, tokenString string, userID int) error {
	// The access token blacklist TTL matches its maximum lifespan; once it
	// expires naturally there is nothing left to track.
	if err := cache.Client.Set(ctx, "blacklist:"+tokenString, "true", AccessTokenTTL).Err(); err != nil {
		return err
	}
	return s.repo.RevokeAllUserRefreshTokens(ctx, userID)
}

// ChangePassword verifies the old password before hashing and saving the new one
func (s *IAMService) ChangePassword(ctx context.Context, userID int, oldPassword, newPassword string) error {
	// Fetch the user to get their current password hash
	user, err := s.repo.GetUserByID(ctx, userID)
	if err != nil {
		return errors.New("user not found")
	}

	if !CheckPasswordHash(oldPassword, user.PasswordHash) {
		return errors.New("incorrect current password")
	}

	hashedPassword, err := HashPassword(newPassword)
	if err != nil {
		return errors.New("failed to secure new password")
	}

	return s.repo.UpdatePassword(ctx, userID, hashedPassword)
}

// ForgotPassword generates a 6-digit OTP and stores it in Redis
func (s *IAMService) ForgotPassword(ctx context.Context, email string) error {
	user, err := s.repo.GetUserByEmail(ctx, email)
	if err != nil {
		return err // Remember: Handler suppresses this error for security
	}

	// Generate a uniformly-random 6-digit OTP. crypto/rand.Int over the exact
	// range avoids the modulo bias the old reduction introduced (backend-bugs #23).
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return errors.New("failed to process password reset")
	}
	otp := fmt.Sprintf("%06d", n.Int64())

	// Store OTP in Redis with a 15-minute expiration, and reset the attempt
	// counter for this address (backend-bugs #21).
	redisKey := "pwd_reset:" + user.Email
	if err := cache.Client.Set(ctx, redisKey, otp, 15*time.Minute).Err(); err != nil {
		return errors.New("failed to process password reset")
	}
	_ = cache.Client.Del(ctx, "pwd_reset_fail:"+user.Email).Err()

	// In a production environment, you would trigger an email or SMS service here:
	// emailService.SendOTP(user.Email, otp)

	// Outside production we print the OTP to the logs so the reset route is
	// testable. In production this would leak reset codes to anyone with log
	// access, so it is gated (backend-bugs #22). The real sender is the actual
	// blocker for a usable production reset flow.
	if !strings.EqualFold(s.appEnv, "production") {
		fmt.Printf("🔒 OTP Generated for %s: %s\n", user.Email, otp)
	}

	return nil
}

// ResetPassword validates the OTP from Redis and forces the password change
func (s *IAMService) ResetPassword(ctx context.Context, email, otp, newPassword string) error {
	redisKey := "pwd_reset:" + email
	failKey := "pwd_reset_fail:" + email

	// A 6-digit OTP with unlimited guesses inside its 15-minute window is
	// brute-forceable; invalidate it after a few wrong attempts (backend-bugs #21).
	if s.isLockedOut(ctx, failKey, maxOTPAttempts) {
		_ = cache.Client.Del(ctx, redisKey).Err()
		return errors.New("too many invalid attempts; request a new OTP")
	}

	// Fetch the saved OTP from Redis
	savedOTP, err := cache.Client.Get(ctx, redisKey).Result()
	if err != nil {
		return errors.New("invalid or expired OTP")
	}

	if savedOTP != otp {
		s.recordFailure(ctx, failKey, 15*time.Minute)
		return errors.New("invalid OTP")
	}

	user, err := s.repo.GetUserByEmail(ctx, email)
	if err != nil {
		return errors.New("user not found")
	}

	hashedPassword, err := HashPassword(newPassword)
	if err != nil {
		return errors.New("failed to secure new password")
	}

	// Update the database
	if err := s.repo.UpdatePassword(ctx, user.ID, hashedPassword); err != nil {
		return errors.New("failed to update password")
	}

	// Delete the OTP and its attempt counter so neither can be reused
	_ = cache.Client.Del(ctx, redisKey)
	_ = cache.Client.Del(ctx, failKey)

	return nil
}
