package main

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/spacesioberyl/system-v1/internal/app"
	"github.com/spacesioberyl/system-v1/internal/broker"
	"github.com/spacesioberyl/system-v1/internal/cache"
	"github.com/spacesioberyl/system-v1/internal/config"
	"github.com/spacesioberyl/system-v1/internal/logger"
	"github.com/spacesioberyl/system-v1/internal/storage"
)

func main() {
	// Load .env (optional in Docker, where env vars are set in docker-compose)
	_ = godotenv.Load()
	cfg := config.Load()

	// 1. Initialize Logger
	logger.Init()
	logger.Log.Info("Starting Spacesio Beryl API...")

	// 2. Connect to PostgreSQL
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	dbPool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	defer dbPool.Close()
	logger.Log.Info("Connected to PostgreSQL successfully")

	// 3. Initialize Redis Cache
	if err := cache.InitRedis(ctx, cfg.RedisURL); err != nil {
		log.Fatalf("Unable to connect to Redis: %v", err)
	}

	// 4. Initialize RabbitMQ Broker
	if err := broker.InitRabbitMQ(cfg.RabbitMQURL); err != nil {
		log.Fatalf("Unable to connect to RabbitMQ: %v", err)
	}
	defer broker.Conn.Close()
	defer broker.Channel.Close()

	// 5. Initialize MinIO Storage
	if err := storage.InitMinIO(cfg.MinIOEndpoint, cfg.MinIOAccessKey, cfg.MinIOSecretKey, cfg.MinIOBucket, cfg.MinIOUseSSL); err != nil {
		// MinIO failure is non-fatal — quotation PDFs will fail but the API will still run
		logger.Log.Error("MinIO initialization failed (PDF generation will be unavailable)", "error", err)
	}

	// 6. Set JWT secret as env var for middleware
	os.Setenv("JWT_SECRET", cfg.JWTSecret)

	// 7. Create and start the Application
	application := app.New(dbPool, cfg)
	if err := application.Start(); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
