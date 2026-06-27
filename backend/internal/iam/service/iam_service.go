package service

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"regexp"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/spacesioberyl/system-v1/internal/cache"
	"github.com/spacesioberyl/system-v1/internal/iam/dto"
	"github.com/spacesioberyl/system-v1/internal/iam/model"
)

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
}

type IAMService struct {
	repo      UserRepository
	jwtSecret string
}

func NewIAMService(repo UserRepository, secret string) *IAMService {
	return &IAMService{
		repo:      repo,
		jwtSecret: secret,
	}
}

// Login handles the core authentication flow
func (s *IAMService) Login(ctx context.Context, req dto.LoginRequest) (*dto.AuthResponse, error) {
	// 1. Fetch user by email
	user, err := s.repo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		return nil, errors.New("invalid credentials")
	}

	// 2. Check if they have been soft-deactivated
	if !user.IsActive {
		return nil, errors.New("account is deactivated")
	}

	// 3. Compare passwords
	if !CheckPasswordHash(req.Password, user.PasswordHash) {
		return nil, errors.New("invalid credentials")
	}

	// 4. Generate Tokens
	accessToken, refreshToken, err := GenerateTokens(user, s.jwtSecret)
	if err != nil {
		return nil, errors.New("failed to generate tokens")
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

	// Fork 1: Check Standard PIN → ghost_mode=false
	if CheckPasswordHash(pin, *user.PinHash) {
		accessToken, _, err := GenerateTokens(user, s.jwtSecret)
		if err != nil {
			return nil, errors.New("failed to generate token")
		}
		return &dto.PinAuthResponse{
			AccessToken: accessToken,
			GhostMode:   false,
		}, nil
	}

	// Fork 2: Check High-Security PIN → ghost_mode=true
	if user.HighSecurityPinHash != nil && CheckPasswordHash(pin, *user.HighSecurityPinHash) {
		accessToken, _, err := GenerateGhostModeTokens(user, s.jwtSecret)
		if err != nil {
			return nil, errors.New("failed to generate token")
		}
		return &dto.PinAuthResponse{
			AccessToken: accessToken,
			GhostMode:   true,
		}, nil
	}

	// Fork 3: Neither PIN matched
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

// RefreshToken validates a 30-day token and mints fresh ones
func (s *IAMService) RefreshToken(ctx context.Context, refreshToken string) (*dto.AuthResponse, error) {
	// 1. Parse and validate the JWT
	claims := &TokenClaims{}
	token, err := jwt.ParseWithClaims(refreshToken, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(s.jwtSecret), nil
	})

	if err != nil || !token.Valid || claims.TokenType != "refresh" {
		return nil, errors.New("invalid or expired refresh token")
	}

	// 2. Fetch the user directly from the Repo using the ID inside the token
	// This ensures we embed their most up-to-date role and department in the new token
	user, err := s.repo.GetUserByID(ctx, claims.UserID)
	if err != nil {
		return nil, errors.New("user no longer exists")
	}

	// 3. Security check: Were they deactivated while offline?
	if !user.IsActive {
		return nil, errors.New("account is deactivated")
	}

	// 4. Generate new tokens (preserve ghost mode state from the original refresh token)
	var newAccessToken, newRefreshToken string
	if claims.GhostMode {
		newAccessToken, newRefreshToken, err = GenerateGhostModeTokens(user, s.jwtSecret)
	} else {
		newAccessToken, newRefreshToken, err = GenerateTokens(user, s.jwtSecret)
	}
	if err != nil {
		return nil, errors.New("failed to generate new tokens")
	}

	return &dto.AuthResponse{
		AccessToken:  newAccessToken,
		RefreshToken: newRefreshToken,
		// Notice we omit the full User object here to keep the payload lightweight
	}, nil
}

// Logout adds the active JWT to the Redis blacklist
func (s *IAMService) Logout(ctx context.Context, tokenString string) error {
	// We set a TTL of 1 hour on the Redis key because that is the maximum lifespan
	// of an access token. Once it expires naturally, we don't need to track it anymore.
	return cache.Client.Set(ctx, "blacklist:"+tokenString, "true", time.Hour).Err()
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

	// Generate a secure 6-digit OTP
	b := make([]byte, 3)
	_, _ = rand.Read(b)
	otp := fmt.Sprintf("%06d", (int(b[0])<<16|int(b[1])<<8|int(b[2])) % 1000000)

	// Store OTP in Redis with a 15-minute expiration
	redisKey := "pwd_reset:" + user.Email
	if err := cache.Client.Set(ctx, redisKey, otp, 15*time.Minute).Err(); err != nil {
		return errors.New("failed to process password reset")
	}

	// In a production environment, you would trigger an email or SMS service here:
	// emailService.SendOTP(user.Email, otp)

	// For local development, we print it to the Docker logs so you can test the reset route
	fmt.Printf("🔒 OTP Generated for %s: %s\n", user.Email, otp)

	return nil
}

// ResetPassword validates the OTP from Redis and forces the password change
func (s *IAMService) ResetPassword(ctx context.Context, email, otp, newPassword string) error {
	redisKey := "pwd_reset:" + email

	// Fetch the saved OTP from Redis
	savedOTP, err := cache.Client.Get(ctx, redisKey).Result()
	if err != nil {
		return errors.New("invalid or expired OTP")
	}

	if savedOTP != otp {
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

	// Delete the OTP from Redis so it cannot be reused
	_ = cache.Client.Del(ctx, redisKey)

	return nil
}
