package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/hr/model"
)

type ExpenseRepository struct {
	db *pgxpool.Pool
}

func NewExpenseRepository(db *pgxpool.Pool) *ExpenseRepository {
	return &ExpenseRepository{db: db}
}

// Create inserts a new office expense record
func (r *ExpenseRepository) Create(ctx context.Context, e *model.Expense) (*model.Expense, error) {
	query := `
		INSERT INTO office_expenses (logged_by, amount, person_paid, context, expense_date, receipt_url)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, logged_by, amount, person_paid, context, expense_date, receipt_url, created_at, updated_at
	`
	var result model.Expense
	err := r.db.QueryRow(ctx, query, e.LoggedBy, e.Amount, e.PersonPaid, e.Context, e.ExpenseDate, e.ReceiptURL).Scan(
		&result.ID, &result.LoggedBy, &result.Amount, &result.PersonPaid,
		&result.Context, &result.ExpenseDate, &result.ReceiptURL,
		&result.CreatedAt, &result.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

// List returns expenses with optional date and user filters
// List returns a page of expenses plus the total matching the filters (#30).
func (r *ExpenseRepository) List(ctx context.Context, startDate, endDate string, loggedBy, limit, offset int) ([]*model.Expense, int, error) {
	where := " WHERE 1=1"
	args := []interface{}{}
	if startDate != "" {
		where += fmt.Sprintf(" AND expense_date >= $%d", len(args)+1)
		args = append(args, startDate)
	}
	if endDate != "" {
		where += fmt.Sprintf(" AND expense_date <= $%d", len(args)+1)
		args = append(args, endDate)
	}
	if loggedBy > 0 {
		where += fmt.Sprintf(" AND logged_by = $%d", len(args)+1)
		args = append(args, loggedBy)
	}

	var total int
	if err := r.db.QueryRow(ctx, "SELECT COUNT(*) FROM office_expenses"+where, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `SELECT id, logged_by, amount, person_paid, context, expense_date, receipt_url, created_at, updated_at FROM office_expenses` +
		where + fmt.Sprintf(" ORDER BY expense_date DESC, created_at DESC LIMIT $%d OFFSET $%d", len(args)+1, len(args)+2)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var expenses []*model.Expense
	for rows.Next() {
		var e model.Expense
		err := rows.Scan(
			&e.ID, &e.LoggedBy, &e.Amount, &e.PersonPaid,
			&e.Context, &e.ExpenseDate, &e.ReceiptURL,
			&e.CreatedAt, &e.UpdatedAt,
		)
		if err != nil {
			return nil, 0, err
		}
		expenses = append(expenses, &e)
	}
	return expenses, total, rows.Err()
}

// GetByID fetches a single expense by ID
func (r *ExpenseRepository) GetByID(ctx context.Context, id int) (*model.Expense, error) {
	query := `
		SELECT id, logged_by, amount, person_paid, context, expense_date, receipt_url, created_at, updated_at
		FROM office_expenses WHERE id = $1
	`
	var e model.Expense
	err := r.db.QueryRow(ctx, query, id).Scan(
		&e.ID, &e.LoggedBy, &e.Amount, &e.PersonPaid,
		&e.Context, &e.ExpenseDate, &e.ReceiptURL,
		&e.CreatedAt, &e.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("expense not found")
		}
		return nil, err
	}
	return &e, nil
}
