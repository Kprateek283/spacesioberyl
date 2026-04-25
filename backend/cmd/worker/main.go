package main

import (
	"context"
	"encoding/json"
	"os"
	"os/signal"
	"syscall"

	"github.com/spacesioberyl/system-v1/internal/broker"
	"github.com/spacesioberyl/system-v1/internal/config"
	"github.com/spacesioberyl/system-v1/internal/db"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

func main() {
	logger.Init()
	logger.Log.Info("Starting Worker container...")

	cfg := config.Load()
	ctx := context.Background()

	if err := db.InitPostgres(ctx, cfg.DatabaseURL); err != nil {
		logger.Log.Error("Postgres init failed", "error", err.Error())
		os.Exit(1)
	}

	if err := broker.InitRabbitMQ(cfg.RabbitMQURL); err != nil {
		logger.Log.Error("RabbitMQ init failed", "error", err.Error())
		os.Exit(1)
	}
	defer broker.Conn.Close()
	defer broker.Channel.Close()

	createTableSQL := `
	CREATE TABLE IF NOT EXISTS system_logs (
		id SERIAL PRIMARY KEY,
		status VARCHAR(50) NOT NULL,
		ping_timestamp TIMESTAMP NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);`
	if _, err := db.Pool.Exec(ctx, createTableSQL); err != nil {
		logger.Log.Error("Failed to create system_logs table", "error", err.Error())
		os.Exit(1)
	}

	msgs, err := broker.Channel.Consume(
		"sync_queue", "", false, false, false, false, nil,
	)
	if err != nil {
		logger.Log.Error("Failed to register a consumer", "error", err.Error())
		os.Exit(1)
	}

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		for d := range msgs {
			logger.Log.Info("Received a message", "body", string(d.Body))

			var payload map[string]string
			if err := json.Unmarshal(d.Body, &payload); err != nil {
				logger.Log.Error("Failed to unmarshal JSON", "error", err.Error())
				d.Nack(false, false)
				continue
			}

			insertSQL := `INSERT INTO system_logs (status, ping_timestamp) VALUES ($1, $2)`
			_, err := db.Pool.Exec(ctx, insertSQL, payload["status"], payload["timestamp"])

			if err != nil {
				logger.Log.Error("Failed to insert into database", "error", err.Error())
				d.Nack(false, true)
				continue
			}

			logger.Log.Info("Successfully saved to PostgreSQL!")
			d.Ack(false)
		}
	}()

	logger.Log.Info("Worker is actively listening for tasks...")
	<-quit
	logger.Log.Info("Worker shutting down gracefully...")
}
