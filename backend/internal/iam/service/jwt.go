package service

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/spacesioberyl/system-v1/internal/iam/model"
)

// Token lifetimes. RefreshTokenTTL is also the lifetime persisted for the
// server-side refresh-token row, so the two never drift.
const (
	AccessTokenTTL  = 1 * time.Hour
	RefreshTokenTTL = 30 * 24 * time.Hour
)

// TokenClaims represents the payload inside the JWT
type TokenClaims struct {
	UserID     int              `json:"user_id"`
	Role       model.RoleName   `json:"role"`
	Department model.Department `json:"department"`
	TokenType  string           `json:"token_type"` // "access" or "refresh"
	GhostMode  bool             `json:"ghost_mode"`  // Ghost Mode: true = cash transactions visible
	jwt.RegisteredClaims
}

// GenerateTokens creates both the Access and Refresh tokens (standard mode, ghost_mode=false).
// The third return value is the refresh token's jti, which the caller must persist.
func GenerateTokens(user *model.User, secret string) (string, string, string, error) {
	return generateTokensWithGhostMode(user, secret, false)
}

// GenerateGhostModeTokens creates tokens with ghost_mode=true (cash transactions visible).
func GenerateGhostModeTokens(user *model.User, secret string) (string, string, string, error) {
	return generateTokensWithGhostMode(user, secret, true)
}

// generateTokensWithGhostMode is the shared implementation. It returns
// (accessToken, refreshToken, refreshJTI, error) — the jti uniquely identifies
// the refresh token in the refresh_tokens table for rotation and revocation.
func generateTokensWithGhostMode(user *model.User, secret string, ghostMode bool) (string, string, string, error) {
	key := []byte(secret)

	// 1. Access Token (1 Hour)
	accessClaims := TokenClaims{
		UserID:     user.ID,
		Role:       user.RoleName, // Assuming we fetched this via JOIN
		Department: user.Department,
		TokenType:  "access",
		GhostMode:  ghostMode,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(AccessTokenTTL)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenString, err := accessToken.SignedString(key)
	if err != nil {
		return "", "", "", err
	}

	// 2. Refresh Token (30 Days) - Powers the local PIN logic!
	// The jti ties this token to a single server-side row so it can be rotated
	// on refresh and revoked on logout.
	jti := uuid.NewString()
	refreshClaims := TokenClaims{
		UserID:    user.ID,
		TokenType: "refresh",
		GhostMode: ghostMode,
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        jti,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(RefreshTokenTTL)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshTokenString, err := refreshToken.SignedString(key)
	if err != nil {
		return "", "", "", err
	}

	return accessTokenString, refreshTokenString, jti, nil
}
