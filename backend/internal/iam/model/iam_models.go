package model

import "time"

// RoleName Define custom types for our PostgreSQL ENUMs to ensure type safety in Go
type RoleName string
type Department string

const (
	RoleSuperAdmin RoleName = "super_admin"
	RoleAdmin      RoleName = "admin"
	RoleStaff      RoleName = "staff"

	DeptOperations Department = "operations"
	DeptTechnical  Department = "technical"
	DeptAccounts   Department = "accounts"
	DeptSales      Department = "sales"
	DeptManagement Department = "management"
)

// Role represents the 'roles' table
type Role struct {
	ID          int       `db:"id"`
	Name        RoleName  `db:"name"`
	Description string    `db:"description"`
	CreatedAt   time.Time `db:"created_at"`
}

// User represents the 'users' table
type User struct {
	ID           int        `db:"id"`
	Name         string     `db:"name"`
	Email        string     `db:"email"`
	PasswordHash string     `db:"password_hash" json:"-"` // Never exposed in JSON
	RoleID       int        `db:"role_id"`
	Department   Department `db:"department"`
	IsActive     bool       `db:"is_active"`
	CreatedAt    time.Time  `db:"created_at"`
	UpdatedAt    time.Time  `db:"updated_at"`

	// Ghost Mode: Dual-PIN fields (nullable — only Super Admin uses these)
	PinHash             *string `db:"pin_hash" json:"-"`
	HighSecurityPinHash *string `db:"high_security_pin_hash" json:"-"`

	// Joined field: Used when we fetch a user and join the roles table
	RoleName RoleName `db:"role_name"`
}
