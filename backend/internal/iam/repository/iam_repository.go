package repository

import (
	"context"
	"errors"

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
