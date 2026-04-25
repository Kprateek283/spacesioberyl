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
	logger.Init()
	logger.Log.Info("Starting API container...")

	cfg := config.Load()
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
	defer broker.Conn.Close()
	defer broker.Channel.Close()

	// Declare the Queue
	_, err := broker.Channel.QueueDeclare(
		"sync_queue", true, false, false, false, nil,
	)
	if err != nil {
		logger.Log.Error("Failed to declare queue", "error", err.Error())
		os.Exit(1)
	}

	// Setup Router
	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	r.Post("/api/v1/ping", handlePing)

	logger.Log.Info("API listening on port " + cfg.APIPort)
	if err := http.ListenAndServe(":"+cfg.APIPort, r); err != nil {
		logger.Log.Error("Server failed to start", "error", err.Error())
		os.Exit(1)
	}
}

func handlePing(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	timestamp := time.Now().UTC().Format(time.RFC3339)

	err := cache.Client.Set(ctx, "last_ping", timestamp, 0).Err()
	if err != nil {
		logger.Log.Error("Failed to set redis key", "error", err.Error())
		http.Error(w, "Cache Error", http.StatusInternalServerError)
		return
	}

	payload := map[string]string{
		"status":    "ping_received",
		"timestamp": timestamp,
	}
	body, _ := json.Marshal(payload)

	err = broker.Channel.PublishWithContext(ctx, "", "sync_queue", false, false, amqp.Publishing{
		ContentType:  "application/json",
		Body:         body,
		DeliveryMode: amqp.Persistent,
	})
	if err != nil {
		logger.Log.Error("Failed to publish message", "error", err.Error())
		http.Error(w, "Broker Error", http.StatusInternalServerError)
		return
	}

	logger.Log.Info("Ping successfully processed and queued")
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(body)
}
