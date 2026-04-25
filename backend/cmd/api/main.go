package main

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	amqp "github.com/rabbitmq/amqp091-go"

	"github.com/spacesioberyl/system-v1/internal/broker"
	"github.com/spacesioberyl/system-v1/internal/cache"
	"github.com/spacesioberyl/system-v1/internal/config"
	"github.com/spacesioberyl/system-v1/internal/db"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

func main() {
	// 1. Initialize Logger
	logger.Init()
	logger.Log.Info("Starting API container...")

	// 2. Load Config
	cfg := config.Load()

	// 3. Initialize Connections
	ctx := context.Background()

	if err := db.InitPostgres(ctx, cfg.DatabaseURL); err != nil {
		logger.Log.Error("Postgres init failed", "error", err.Error())
		os.Exit(1)
	}

	if err := cache.InitRedis(ctx, cfg.RedisURL); err != nil {
		logger.Log.Error("Redis init failed", "error", err.Error())
		os.Exit(1)
	}

	if err := broker.InitRabbitMQ(cfg.RabbitMQURL); err != nil {
		logger.Log.Error("RabbitMQ init failed", "error", err.Error())
		os.Exit(1)
	}
	// Note: In production, you'd handle graceful shutdowns here
	defer broker.Conn.Close()
	defer broker.Channel.Close()

	// 4. Declare the RabbitMQ Queue (Ensures it exists before publishing)
	_, err := broker.Channel.QueueDeclare(
		"sync_queue", // Queue name
		true,         // Durable (survives broker restarts)
		false,        // Auto-delete
		false,        // Exclusive
		false,        // No-wait
		nil,          // Arguments
	)
	if err != nil {
		logger.Log.Error("Failed to declare queue", "error", err.Error())
		os.Exit(1)
	}

	// 5. Setup Router
	r := chi.NewRouter()
	r.Use(middleware.Logger)    // Logs HTTP requests to stdout
	r.Use(middleware.Recoverer) // Prevents the API from crashing on panics

	// 6. Define Routes
	r.Post("/api/v1/ping", handlePing)

	// 7. Start Server
	logger.Log.Info("API listening on port " + cfg.APIPort)
	if err := http.ListenAndServe(":"+cfg.APIPort, r); err != nil {
		logger.Log.Error("Server failed to start", "error", err.Error())
		os.Exit(1)
	}
}

// handlePing processes the test request, hits Redis, and publishes to RabbitMQ
func handlePing(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	timestamp := time.Now().UTC().Format(time.RFC3339)

	// Step A: Cache the timestamp in Redis
	err := cache.Client.Set(ctx, "last_ping", timestamp, 0).Err()
	if err != nil {
		logger.Log.Error("Failed to set redis key", "error", err.Error())
		http.Error(w, "Cache Error", http.StatusInternalServerError)
		return
	}

	// Step B: Create the payload and publish to RabbitMQ
	payload := map[string]string{
		"status":    "ping_received",
		"timestamp": timestamp,
	}
	body, _ := json.Marshal(payload)

	err = broker.Channel.PublishWithContext(ctx,
		"",           // Exchange (empty string means default direct exchange)
		"sync_queue", // Routing key (matches the queue name)
		false,        // Mandatory
		false,        // Immediate
		amqp.Publishing{
			ContentType:  "application/json",
			Body:         body,
			DeliveryMode: amqp.Persistent, // Ensure the message is written to disk
		})
	if err != nil {
		logger.Log.Error("Failed to publish message", "error", err.Error())
		http.Error(w, "Broker Error", http.StatusInternalServerError)
		return
	}

	logger.Log.Info("Ping successfully processed and queued")

	// Step C: Respond to the client
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(body)
}
