package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/spacesioberyl/system-v1/internal/broker"
	"github.com/spacesioberyl/system-v1/internal/config"
	crmRepo "github.com/spacesioberyl/system-v1/internal/crm/repository"
	logRepo "github.com/spacesioberyl/system-v1/internal/logistics/repository"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

// CONFIGURABLE THRESHOLDS (adjust these as needed)
const (
	// ComplaintEscalationHours is the number of hours after which an unresolved complaint is auto-escalated.
	// Default: 48 hours. Change this value if the business policy changes.
	ComplaintEscalationHours = 48

	// FollowUpMissedHours is the number of hours past the scheduled time after which a follow-up is marked as missed.
	// Default: 24 hours. Change this value if the business policy changes.
	FollowUpMissedHours = 24

	// CronIntervalMinutes is how frequently the cron jobs run.
	CronIntervalMinutes = 15
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()
	logger.Init()
	logger.Log.Info("Starting Spacesio Beryl Worker...")

	// 1. Connect to PostgreSQL (with retry — DB may not be ready yet)
	var dbPool *pgxpool.Pool
	for i := 1; i <= 5; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
		cancel()
		if err == nil {
			dbPool = pool
			break
		}
		logger.Log.Warn(fmt.Sprintf("Database connection failed (attempt %d/5). Retrying in 2 seconds...", i), "error", err)
		time.Sleep(2 * time.Second)
	}
	if dbPool == nil {
		log.Fatalf("Worker: Unable to connect to database after 5 attempts")
	}
	defer dbPool.Close()
	logger.Log.Info("Connected to PostgreSQL successfully")

	// 2. Connect to RabbitMQ (with retry — RabbitMQ takes ~15-20s to be ready in Docker)
	for i := 1; i <= 10; i++ {
		err := broker.InitRabbitMQ(cfg.RabbitMQURL)
		if err == nil {
			break
		}
		logger.Log.Warn(fmt.Sprintf("RabbitMQ connection failed (attempt %d/10). Retrying in 3 seconds...", i), "error", err)
		if i == 10 {
			log.Fatalf("Worker: Unable to connect to RabbitMQ after 10 attempts: %v", err)
		}
		time.Sleep(3 * time.Second)
	}
	defer broker.Conn.Close()
	defer broker.Channel.Close()

	// 3. Initialize repositories (the worker reads/writes directly to the DB)
	complaintRepo := crmRepo.NewComplaintRepository(dbPool)
	followUpRepo := crmRepo.NewFollowUpRepository(dbPool)
	logisticsRepo := logRepo.NewLogisticsRepository(dbPool)

	// 4. Start queue consumers (goroutines)
	go consumeQuoteApproved(logisticsRepo)
	go consumeInstallationSignoff(dbPool)
	go consumeWhatsApp(cfg)

	// 5. Start cron jobs (goroutines)
	go runCronJob("Complaint Escalation", CronIntervalMinutes, func() {
		escalateComplaints(complaintRepo)
	})
	go runCronJob("Follow-Up Missed", CronIntervalMinutes, func() {
		markMissedFollowUps(followUpRepo)
	})

	// 6. Block until shutdown signal
	logger.Log.Info("Worker is running. Waiting for events and cron ticks...")
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh
	logger.Log.Info("Worker shutting down gracefully...")
}

// =====================================================
// QUEUE CONSUMER: Quote Approved (Module 3 → 4 Handoff)
// =====================================================

type QuoteApprovedEvent struct {
	QuotationID     int    `json:"quotation_id"`
	LeadID          int    `json:"lead_id"`
	PaymentTermType string `json:"payment_term_type"`
}

func consumeQuoteApproved(logisticsRepo *logRepo.LogisticsRepository) {
	ch, err := broker.Conn.Channel()
	if err != nil {
		logger.Log.Error("Failed to open channel for quote_approved consumer", "error", err)
		return
	}
	defer ch.Close()

	msgs, err := ch.Consume(broker.QueueQuoteApproved, "worker-quote", false, false, false, false, nil)
	if err != nil {
		logger.Log.Error("Failed to start consuming quote_approved queue", "error", err)
		return
	}

	logger.Log.Info("Consumer started", "queue", broker.QueueQuoteApproved)

	for msg := range msgs {
		processQuoteApproved(msg, logisticsRepo)
	}
}

func processQuoteApproved(msg amqp.Delivery, logisticsRepo *logRepo.LogisticsRepository) {
	var event QuoteApprovedEvent
	if err := json.Unmarshal(msg.Body, &event); err != nil {
		logger.Log.Error("Failed to unmarshal quote_approved event", "error", err)
		msg.Nack(false, false)
		return
	}

	logger.Log.Info("Processing quote_approved event", "quotation_id", event.QuotationID, "lead_id", event.LeadID)

	// Create an Order from the approved quotation (the Module 3 → 4 handoff)
	orderID, err := logisticsRepo.CreateOrderFromQuotation(context.Background(), event.QuotationID, event.LeadID, event.PaymentTermType)
	if err != nil {
		logger.Log.Error("Failed to create order from quotation", "quotation_id", event.QuotationID, "error", err)
		msg.Nack(false, true)
		return
	}

	logger.Log.Info("✅ Order created from approved quotation", "order_id", orderID, "quotation_id", event.QuotationID)
	msg.Ack(false)
}

// =====================================================
// QUEUE CONSUMER: Installation Signoff (Financial Lock)
// =====================================================

type InstallationSignoffEvent struct {
	InstallationID int `json:"installation_id"`
	OrderID        int `json:"order_id"`
}

func consumeInstallationSignoff(dbPool *pgxpool.Pool) {
	ch, err := broker.Conn.Channel()
	if err != nil {
		logger.Log.Error("Failed to open channel for installation_signoff consumer", "error", err)
		return
	}
	defer ch.Close()

	msgs, err := ch.Consume(broker.QueueInstallationSignoff, "worker-signoff", true, false, false, false, nil)
	if err != nil {
		logger.Log.Error("Failed to start consuming installation_signoff queue", "error", err)
		return
	}

	logger.Log.Info("Consumer started", "queue", broker.QueueInstallationSignoff)

	for msg := range msgs {
		processInstallationSignoff(msg, dbPool)
	}
}

func processInstallationSignoff(msg amqp.Delivery, dbPool *pgxpool.Pool) {
	var event InstallationSignoffEvent
	if err := json.Unmarshal(msg.Body, &event); err != nil {
		logger.Log.Error("Failed to unmarshal installation_signoff event", "error", err)
		return
	}

	logger.Log.Info("Processing installation_signoff event (Financial Lock)",
		"installation_id", event.InstallationID, "order_id", event.OrderID)

	// Look up the order to get payment term type, then trace back to quotation
	var paymentTermType string
	err := dbPool.QueryRow(context.Background(),
		`SELECT COALESCE(o.payment_term_type, q.payment_term_type, 'unknown')
		 FROM orders o
		 JOIN quotations q ON o.quotation_id = q.id
		 WHERE o.id = $1`, event.OrderID,
	).Scan(&paymentTermType)
	if err != nil {
		logger.Log.Error("Financial Lock: Failed to look up payment terms",
			"order_id", event.OrderID, "error", err)
		return
	}

	// Log the financial lock notification (Accounts team action required)
	logger.Log.Info("💰 FINANCIAL LOCK TRIGGERED — Accounts team notification",
		"installation_id", event.InstallationID,
		"order_id", event.OrderID,
		"payment_term_type", paymentTermType,
		"action", "Collect final payment per quotation terms",
	)

	// Update the order status to reflect that installation is complete
	_, err = dbPool.Exec(context.Background(),
		`UPDATE orders SET status = 'installation_complete', updated_at = CURRENT_TIMESTAMP WHERE id = $1`,
		event.OrderID,
	)
	if err != nil {
		logger.Log.Error("Financial Lock: Failed to update order status", "order_id", event.OrderID, "error", err)
	}
}

// =====================================================
// CRON JOB HELPERS
// =====================================================

func runCronJob(name string, intervalMinutes int, job func()) {
	ticker := time.NewTicker(time.Duration(intervalMinutes) * time.Minute)
	defer ticker.Stop()

	// Run once immediately on startup
	logger.Log.Info(fmt.Sprintf("Cron job '%s' started (interval: %dm)", name, intervalMinutes))
	job()

	for range ticker.C {
		job()
	}
}

func escalateComplaints(repo *crmRepo.ComplaintRepository) {
	count, err := repo.EscalateOld(context.Background(), ComplaintEscalationHours)
	if err != nil {
		logger.Log.Error("Complaint escalation failed", "error", err)
		return
	}
	if count > 0 {
		logger.Log.Info("🔴 Complaints escalated", "count", count, "threshold_hours", ComplaintEscalationHours)
	}
}

func markMissedFollowUps(repo *crmRepo.FollowUpRepository) {
	count, err := repo.MarkMissed(context.Background(), FollowUpMissedHours)
	if err != nil {
		logger.Log.Error("Follow-up missed marking failed", "error", err)
		return
	}
	if count > 0 {
		logger.Log.Info("⚠️ Follow-ups marked as missed", "count", count, "threshold_hours", FollowUpMissedHours)
	}
}
