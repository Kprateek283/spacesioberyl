package service

import (
	"context"
	"errors"
	"time"

	"github.com/spacesioberyl/system-v1/internal/hr/dto"
	"github.com/spacesioberyl/system-v1/internal/hr/model"
	"github.com/spacesioberyl/system-v1/internal/hr/repository"
)

type ExpenseService struct {
	repo *repository.ExpenseRepository
}

func NewExpenseService(repo *repository.ExpenseRepository) *ExpenseService {
	return &ExpenseService{repo: repo}
}

// Create logs a new office expense
func (s *ExpenseService) Create(ctx context.Context, userID int, req dto.CreateExpenseRequest) (*model.Expense, error) {
	if req.Amount <= 0 {
		return nil, errors.New("amount must be greater than zero")
	}
	if req.PersonPaid == "" || req.Context == "" {
		return nil, errors.New("person_paid and context are required")
	}

	var receiptURL *string
	if req.ReceiptURL != "" {
		receiptURL = &req.ReceiptURL
	}

	var expenseDate time.Time
	if req.ExpenseDate != "" {
		parsed, err := time.Parse("2006-01-02", req.ExpenseDate)
		if err != nil {
			return nil, errors.New("invalid expense_date format (expected YYYY-MM-DD)")
		}
		expenseDate = parsed
	} else {
		expenseDate = time.Now()
	}

	expense := &model.Expense{
		LoggedBy:    userID,
		Amount:      req.Amount,
		PersonPaid:  req.PersonPaid,
		Context:     req.Context,
		ExpenseDate: expenseDate,
		ReceiptURL:  receiptURL,
	}
	return s.repo.Create(ctx, expense)
}

// List returns expenses with optional filters
func (s *ExpenseService) List(ctx context.Context, startDate, endDate string, loggedBy int) ([]*model.Expense, error) {
	return s.repo.List(ctx, startDate, endDate, loggedBy)
}

// GetByID returns a single expense record
func (s *ExpenseService) GetByID(ctx context.Context, id int) (*model.Expense, error) {
	return s.repo.GetByID(ctx, id)
}
