package main

import (
	"context"
	"log"
	"net/http"
	"os/signal"
	"syscall"
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

	// 2. Reject an unsafe configuration before opening any connections
	if err := cfg.Validate(); err != nil {
		log.Fatalf("Invalid configuration: %v", err)
	}

	// 3. Connect to PostgreSQL
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
	defer broker.Close()

	// 5. Initialize MinIO Storage. Fatal on failure: a non-fatal init trades a
	// loud startup error for a confusing 500 (or, pre-guard, a panic) at an
	// arbitrary later upload (backend-bugs #18).
	if err := storage.InitMinIO(cfg.MinIOEndpoint, cfg.MinIOAccessKey, cfg.MinIOSecretKey, cfg.MinIOBucket, cfg.MinIOUseSSL, cfg.MinIOPublicURL); err != nil {
		log.Fatalf("Unable to initialize MinIO storage: %v", err)
	}

	// 7. Create and start the Application.
	// The JWT secret is passed to the middleware via app.New — no env round-trip.
	application := app.New(dbPool, cfg)

	// Run the server in the background and wait for either a fatal serve error or
	// a shutdown signal. On signal, drain in-flight requests within a bounded
	// window so this function returns normally and the deferred DB pool / broker
	// closes above actually run (backend-bugs #17).
	serveErr := make(chan error, 1)
	go func() { serveErr <- application.Start() }()

	sigCtx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	select {
	case err := <-serveErr:
		if err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed to start: %v", err)
		}
	case <-sigCtx.Done():
		stop() // stop intercepting signals; a second Ctrl-C now force-quits
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		if err := application.Shutdown(shutdownCtx); err != nil {
			logger.Log.Error("Graceful shutdown failed", "error", err)
		}
	}
	logger.Log.Info("Spacesio Beryl API stopped")
}
