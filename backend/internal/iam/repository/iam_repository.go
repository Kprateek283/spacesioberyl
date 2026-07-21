package repository

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/iam/model"
)

type IAMRepository struct {
	db *pgxpool.Pool
}

func NewIAMRepository(db *pgxpool.Pool) *IAMRepository {
	return &IAMRepository{db: db}
}

// GetUserByEmail fetches a user and joins their role name for the JWT payload
func (r *IAMRepository) GetUserByEmail(ctx context.Context, email string) (*model.User, error) {
	query := `
		SELECT u.id, u.name, u.email, u.password_hash, u.role_id, u.department, u.is_active,
		       u.pin_hash, u.high_security_pin_hash, r.name as role_name
		FROM users u
		JOIN roles r ON u.role_id = r.id
		WHERE u.email = $1
	`
	var user model.User
	err := r.db.QueryRow(ctx, query, email).Scan(
		&user.ID, &user.Name, &user.Email, &user.PasswordHash,
		&user.RoleID, &user.Department, &user.IsActive,
		&user.PinHash, &user.HighSecurityPinHash, &user.RoleName,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("user not found")
		}
		return nil, err
	}
	return &user, nil
}

// GetRoleIDByName fetches the numeric ID for a string role (e.g., "staff")
func (r *IAMRepository) GetRoleIDByName(ctx context.Context, roleName string) (int, error) {
	var id int
	err := r.db.QueryRow(ctx, "SELECT id FROM roles WHERE name = $1", roleName).Scan(&id)
	return id, err
}

// CreateUser inserts a new user and returns their new ID
func (r *IAMRepository) CreateUser(ctx context.Context, user *model.User) (int, error) {
	query := `
		INSERT INTO users (name, email, password_hash, role_id, department, is_active)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id
	`
	var id int
	err := r.db.QueryRow(ctx, query,
		user.Name, user.Email, user.PasswordHash,
		user.RoleID, user.Department, user.IsActive,
	).Scan(&id)

	return id, err
}

// UpdateUserStatus handles the soft-deactivation toggle
func (r *IAMRepository) UpdateUserStatus(ctx context.Context, userID int, isActive bool) error {
	query := `UPDATE users SET is_active = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`
	commandTag, err := r.db.Exec(ctx, query, isActive, userID)
	if err != nil {
		return err
	}
	if commandTag.RowsAffected() == 0 {
		return errors.New("user not found")
	}
	return nil
}

// GetUserByID fetches a user by their primary key
func (r *IAMRepository) GetUserByID(ctx context.Context, id int) (*model.User, error) {
	query := `
		SELECT u.id, u.name, u.email, u.password_hash, u.role_id, u.department, u.is_active,
		       u.pin_hash, u.high_security_pin_hash, r.name as role_name
		FROM users u
		JOIN roles r ON u.role_id = r.id
		WHERE u.id = $1
	`
	var user model.User
	err := r.db.QueryRow(ctx, query, id).Scan(
		&user.ID, &user.Name, &user.Email, &user.PasswordHash,
		&user.RoleID, &user.Department, &user.IsActive,
		&user.PinHash, &user.HighSecurityPinHash, &user.RoleName,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("user not found")
		}
		return nil, err
	}
	return &user, nil
}

// ListUsers fetches all users in the system, ordered by creation date
func (r *IAMRepository) ListUsers(ctx context.Context) ([]*model.User, error) {
	query := `
		SELECT u.id, u.name, u.email, u.password_hash, u.role_id, u.department, u.is_active,
		       u.pin_hash, u.high_security_pin_hash, r.name as role_name
		FROM users u
		JOIN roles r ON u.role_id = r.id
		ORDER BY u.created_at DESC
	`
	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []*model.User
	for rows.Next() {
		var user model.User
		err := rows.Scan(
			&user.ID, &user.Name, &user.Email, &user.PasswordHash,
			&user.RoleID, &user.Department, &user.IsActive,
			&user.PinHash, &user.HighSecurityPinHash, &user.RoleName,
		)
		if err != nil {
			return nil, err
		}
		users = append(users, &user)
	}
	return users, rows.Err()
}

// UpdatePassword forcefully updates a user's password hash
func (r *IAMRepository) UpdatePassword(ctx context.Context, userID int, newHash string) error {
	query := `UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`

	commandTag, err := r.db.Exec(ctx, query, newHash, userID)
	if err != nil {
		return err
	}

	if commandTag.RowsAffected() == 0 {
		return errors.New("user not found")
	}

	return nil
}

// InsertRefreshToken records a newly issued refresh token so it can later be
// rotated or revoked (backend-bugs #7/#8).
func (r *IAMRepository) InsertRefreshToken(ctx context.Context, userID int, jti string, ghostMode bool, expiresAt time.Time) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO refresh_tokens (user_id, jti, ghost_mode, expires_at) VALUES ($1, $2, $3, $4)`,
		userID, jti, ghostMode, expiresAt)
	return err
}

// GetRefreshTokenByJTI looks up a stored refresh token by its jti. A missing row
// (unknown or pruned token) returns pgx.ErrNoRows.
func (r *IAMRepository) GetRefreshTokenByJTI(ctx context.Context, jti string) (*model.RefreshToken, error) {
	var t model.RefreshToken
	err := r.db.QueryRow(ctx,
		`SELECT id, user_id, jti, ghost_mode, expires_at, revoked_at, created_at
		 FROM refresh_tokens WHERE jti = $1`, jti).Scan(
		&t.ID, &t.UserID, &t.JTI, &t.GhostMode, &t.ExpiresAt, &t.RevokedAt, &t.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &t, nil
}

// RevokeRefreshToken marks a single refresh token revoked (used on rotation).
func (r *IAMRepository) RevokeRefreshToken(ctx context.Context, jti string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE refresh_tokens SET revoked_at = CURRENT_TIMESTAMP WHERE jti = $1 AND revoked_at IS NULL`, jti)
	return err
}

// RevokeAllUserRefreshTokens revokes every active refresh token for a user
// (used on logout and on refresh-token reuse detection).
func (r *IAMRepository) RevokeAllUserRefreshTokens(ctx context.Context, userID int) error {
	_, err := r.db.Exec(ctx,
		`UPDATE refresh_tokens SET revoked_at = CURRENT_TIMESTAMP WHERE user_id = $1 AND revoked_at IS NULL`, userID)
	return err
}

// SetupPins stores both hashed PINs for the Super Admin (Ghost Mode initialization)
func (r *IAMRepository) SetupPins(ctx context.Context, userID int, pinHash, highSecPinHash string) error {
	query := `
		UPDATE users 
		SET pin_hash = $1, high_security_pin_hash = $2, updated_at = CURRENT_TIMESTAMP 
		WHERE id = $3
	`
	commandTag, err := r.db.Exec(ctx, query, pinHash, highSecPinHash, userID)
	if err != nil {
		return err
	}
	if commandTag.RowsAffected() == 0 {
		return errors.New("user not found")
	}
	return nil
}
