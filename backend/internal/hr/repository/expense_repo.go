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
func (r *ExpenseRepository) List(ctx context.Context, startDate, endDate string, loggedBy int) ([]*model.Expense, error) {
	query := `
		SELECT id, logged_by, amount, person_paid, context, expense_date, receipt_url, created_at, updated_at
		FROM office_expenses WHERE 1=1
	`
	args := []interface{}{}
	argIdx := 1

	if startDate != "" {
		query += fmt.Sprintf(" AND expense_date >= $%d", argIdx)
		args = append(args, startDate)
		argIdx++
	}
	if endDate != "" {
		query += fmt.Sprintf(" AND expense_date <= $%d", argIdx)
		args = append(args, endDate)
		argIdx++
	}
	if loggedBy > 0 {
		query += fmt.Sprintf(" AND logged_by = $%d", argIdx)
		args = append(args, loggedBy)
		argIdx++
	}
	query += " ORDER BY expense_date DESC, created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
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
			return nil, err
		}
		expenses = append(expenses, &e)
	}
	return expenses, rows.Err()
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
