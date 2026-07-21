package middleware

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/spacesioberyl/system-v1/internal/cache"
)

// contextKey prevents key collisions in the request Context
type contextKey string

const ClaimsKey contextKey = "user_claims"

// TokenClaims matches the payload we defined in the IAM Service
type TokenClaims struct {
	UserID     int    `json:"user_id"`
	Role       string `json:"role"`
	Department string `json:"department"`
	TokenType  string `json:"token_type"`
	GhostMode  bool   `json:"ghost_mode"` // Ghost Mode: true = cash transactions visible
	jwt.RegisteredClaims
}

// Helper to return clean JSON errors from the middleware
func sendAuthError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": message})
}

// RequireAuth returns middleware that ensures the request carries a valid,
// unexpired Access Token signed with the given secret.
func RequireAuth(secret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
				sendAuthError(w, http.StatusUnauthorized, "Missing or invalid Authorization header")
				return
			}

			tokenString := strings.TrimPrefix(authHeader, "Bearer ")

			claims := &TokenClaims{}
			token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
				return []byte(secret), nil
			})

			if err != nil || !token.Valid {
				sendAuthError(w, http.StatusUnauthorized, "Invalid or expired token")
				return
			}

			// Check if this specific token was explicitly logged out. A revocation
			// check must fail closed: if Redis is unreachable we cannot prove the
			// token is still valid, so we reject rather than let a revoked token
			// through (backend-bugs #6).
			isBlacklisted, err := cache.Client.Exists(r.Context(), "blacklist:"+tokenString).Result()
			if err != nil {
				sendAuthError(w, http.StatusServiceUnavailable, "Authorization service temporarily unavailable")
				return
			}
			if isBlacklisted > 0 {
				sendAuthError(w, http.StatusUnauthorized, "Token has been revoked (Logged out)")
				return
			}

			// Security check: Block 30-day Refresh Tokens from being used to access normal APIs
			if claims.TokenType != "access" {
				sendAuthError(w, http.StatusUnauthorized, "Invalid token type. Please use an access token.")
				return
			}

			// Inject the verified claims into the request Context
			ctx := context.WithValue(r.Context(), ClaimsKey, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// RequireRole enforces strict RBAC (e.g., only "admin" or "super_admin" can pass)
func RequireRole(allowedRoles ...string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Extract claims from the context (put there by RequireAuth)
			claims, ok := r.Context().Value(ClaimsKey).(*TokenClaims)
			if !ok {
				sendAuthError(w, http.StatusUnauthorized, "Unauthorized")
				return
			}

			// Check if their role exists in the allowed list
			hasAccess := false
			for _, allowed := range allowedRoles {
				if claims.Role == allowed {
					hasAccess = true
					break
				}
			}

			if !hasAccess {
				sendAuthError(w, http.StatusForbidden, "Forbidden: You do not have permission to perform this action")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// ClientIP returns the client's network address from the socket peer.
// With no reverse proxy in front (the API is directly exposed), r.RemoteAddr is
// the only trustworthy source — forwarded headers are attacker-controlled and
// are deliberately ignored (backend-bugs #4/#11).
func ClientIP(r *http.Request) string {
	if host, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		return host
	}
	return r.RemoteAddr
}

// CanAssignRole reports whether a caller with callerRole may create a user with,
// or promote a user to, targetRole. Only a super_admin may mint another
// super_admin; anything below that any admin/super_admin may assign
// (backend-bugs #10). This is the single place the hierarchy is written down.
func CanAssignRole(callerRole, targetRole string) bool {
	if targetRole == "super_admin" {
		return callerRole == "super_admin"
	}
	return true
}

// GetGhostMode extracts the ghost_mode flag from the request context.
// Returns false if the claim is not present (default: cash transactions hidden).
func GetGhostMode(ctx context.Context) bool {
	claims, ok := ctx.Value(ClaimsKey).(*TokenClaims)
	if !ok {
		return false
	}
	return claims.GhostMode
}
