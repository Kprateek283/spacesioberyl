package broker

import (
	"context"
	"encoding/json"
	"fmt"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

var Conn *amqp.Connection
var Channel *amqp.Channel

// Queues used throughout the system
const (
	QueueSyncQueue           = "sync_queue"           // Legacy POC queue
	QueueQuoteApproved       = "quote_approved"       // Module 3 → 4 handoff
	QueueInstallationSignoff = "installation_signoff" // Module 5 Financial Lock
	QueueWhatsApp            = "whatsapp_queue"       // WhatsApp Cloud API notifications
)

func InitRabbitMQ(url string) error {
	conn, err := amqp.Dial(url)
	if err != nil {
		return fmt.Errorf("failed to connect to rabbitmq: %w", err)
	}

	ch, err := conn.Channel()
	if err != nil {
		return fmt.Errorf("failed to open a channel: %w", err)
	}

	Conn = conn
	Channel = ch
	logger.Log.Info("Connected to RabbitMQ successfully")

	// Declare all queues on startup to ensure they exist
	queues := []string{QueueSyncQueue, QueueQuoteApproved, QueueInstallationSignoff, QueueWhatsApp}
	for _, q := range queues {
		_, err := ch.QueueDeclare(q, true, false, false, false, nil)
		if err != nil {
			return fmt.Errorf("failed to declare queue %s: %w", q, err)
		}
	}
	logger.Log.Info("All RabbitMQ queues declared", "queues", queues)

	return nil
}

// PublishEvent serializes the payload to JSON and publishes to the specified queue.
func PublishEvent(ctx context.Context, queueName string, payload interface{}) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal event payload: %w", err)
	}

	err = Channel.PublishWithContext(ctx, "", queueName, false, false, amqp.Publishing{
		ContentType: "application/json",
		Body:        body,
	})
	if err != nil {
		return fmt.Errorf("failed to publish to %s: %w", queueName, err)
	}

	logger.Log.Info("Event published", "queue", queueName, "payload_size", len(body))
	return nil
}

// PublishWhatsAppNotification is a convenience wrapper for publishing a WhatsApp template notification.
// It marshals the notification struct and pushes it to the whatsapp_queue.
// This is designed to be best-effort: callers should log errors but NOT block the HTTP response.
func PublishWhatsAppNotification(ctx context.Context, phone, templateName string, vars map[string]string) error {
	notif := WhatsAppNotification{
		Phone:        phone,
		TemplateName: templateName,
		Vars:         vars,
	}
	return PublishEvent(ctx, QueueWhatsApp, notif)
}
