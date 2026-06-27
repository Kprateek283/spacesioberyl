package db

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

var Pool *pgxpool.Pool

func InitPostgres(ctx context.Context, dsn string) error {
	var pool *pgxpool.Pool
	var err error

	// Retry connection up to 5 times, waiting 2 seconds between attempts
	for i := 1; i <= 5; i++ {
		pool, err = pgxpool.New(ctx, dsn)
		if err == nil {
			err = pool.Ping(ctx)
		}

		if err == nil {
			Pool = pool
			logger.Log.Info("Connected to PostgreSQL successfully")
			return nil
		}

		logger.Log.Warn(fmt.Sprintf("Database connection failed (attempt %d/5). Retrying in 2 seconds...", i), "error", err.Error())
		time.Sleep(2 * time.Second)
	}

	return fmt.Errorf("unable to connect to database after 5 attempts: %w", err)
}
