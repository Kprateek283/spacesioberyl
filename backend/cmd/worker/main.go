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
	"github.com/spacesioberyl/system-v1/internal/logger"
	logRepo "github.com/spacesioberyl/system-v1/internal/logistics/repository"
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
	defer broker.Close()

	// 3. Initialize repositories (the worker reads/writes directly to the DB)
	complaintRepo := crmRepo.NewComplaintRepository(dbPool)
	followUpRepo := crmRepo.NewFollowUpRepository(dbPool)
	logisticsRepo := logRepo.NewLogisticsRepository(dbPool)

	// 4. Start queue consumers, each supervised so it restarts after a broker
	// reconnect rather than dying on the first connection drop (backend-bugs #14).
	go superviseConsumer("quote_approved", func() error { return consumeQuoteApproved(logisticsRepo) })
	go superviseConsumer("installation_signoff", func() error { return consumeInstallationSignoff(dbPool) })
	if cfg.WhatsAppToken != "" && cfg.WhatsAppPhoneID != "" {
		go superviseConsumer("whatsapp_queue", func() error { return consumeWhatsApp(cfg) })
	} else {
		logger.Log.Warn("WhatsApp consumer disabled — WHATSAPP_TOKEN or WHATSAPP_PHONE_ID not set")
	}

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

// superviseConsumer runs a consumer and restarts it after any exit — an error
// (broker unreachable) or a clean return (the delivery channel closed on a
// connection drop). The broker's own reconnect watcher refreshes the shared
// connection in the background, so the next attempt picks it up (backend-bugs #14).
func superviseConsumer(name string, run func() error) {
	for {
		if err := run(); err != nil {
			logger.Log.Error("Consumer stopped, restarting", "queue", name, "error", err)
		} else {
			logger.Log.Warn("Consumer delivery channel closed, restarting", "queue", name)
		}
		time.Sleep(3 * time.Second)
	}
}

func consumeQuoteApproved(logisticsRepo *logRepo.LogisticsRepository) error {
	ch, err := broker.Conn.Channel()
	if err != nil {
		return fmt.Errorf("open channel: %w", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume(broker.QueueQuoteApproved, "worker-quote", false, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("start consuming: %w", err)
	}

	logger.Log.Info("Consumer started", "queue", broker.QueueQuoteApproved)

	for msg := range msgs {
		processQuoteApproved(msg, logisticsRepo)
	}
	return nil // delivery channel closed → supervisor restarts
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

func consumeInstallationSignoff(dbPool *pgxpool.Pool) error {
	ch, err := broker.Conn.Channel()
	if err != nil {
		return fmt.Errorf("open channel: %w", err)
	}
	defer ch.Close()

	// Manual ack so a poison or transiently-failing message is handled
	// explicitly rather than silently dropped by auto-ack (backend-bugs #14).
	msgs, err := ch.Consume(broker.QueueInstallationSignoff, "worker-signoff", false, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("start consuming: %w", err)
	}

	logger.Log.Info("Consumer started", "queue", broker.QueueInstallationSignoff)

	for msg := range msgs {
		processInstallationSignoff(msg, dbPool)
	}
	return nil // delivery channel closed → supervisor restarts
}

func processInstallationSignoff(msg amqp.Delivery, dbPool *pgxpool.Pool) {
	var event InstallationSignoffEvent
	if err := json.Unmarshal(msg.Body, &event); err != nil {
		// Unparseable message: reject without requeue so it dead-letters for
		// inspection instead of looping forever.
		logger.Log.Error("Failed to unmarshal installation_signoff event", "error", err)
		_ = msg.Nack(false, false)
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
		// Transient (DB blip) — requeue for another attempt.
		logger.Log.Error("Financial Lock: Failed to look up payment terms",
			"order_id", event.OrderID, "error", err)
		_ = msg.Nack(false, true)
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
		// The status update is idempotent, so requeue on a transient failure.
		logger.Log.Error("Financial Lock: Failed to update order status", "order_id", event.OrderID, "error", err)
		_ = msg.Nack(false, true)
		return
	}

	_ = msg.Ack(false)
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
