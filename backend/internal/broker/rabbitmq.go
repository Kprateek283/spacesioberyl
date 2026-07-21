package broker

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

// Conn and Channel are the shared connection/channel. They are swapped atomically
// on reconnect, so read them under brokerMu (or via currentConn) rather than
// caching a stale pointer.
var (
	Conn    *amqp.Connection
	Channel *amqp.Channel

	brokerURL string
	brokerMu  sync.Mutex
)

// Queues used throughout the system
const (
	QueueSyncQueue           = "sync_queue"           // Legacy POC queue
	QueueQuoteApproved       = "quote_approved"       // Module 3 → 4 handoff
	QueueInstallationSignoff = "installation_signoff" // Module 5 Financial Lock
	QueueWhatsApp            = "whatsapp_queue"       // WhatsApp Cloud API notifications

	// Dead-lettering (backend-bugs #14): messages a consumer rejects without
	// requeue land here so poison messages are visible for inspection rather than
	// silently dropped or redelivered forever.
	DeadLetterExchange = "dead_letter_exchange"
	QueueDeadLetter    = "dead_letter_queue"
)

const (
	reconnectDelay     = 3 * time.Second
	publishConfirmWait = 5 * time.Second
	maxPublishAttempts = 3
)

// workQueues are declared with a dead-letter exchange so rejected messages route
// to the DLQ.
var workQueues = []string{QueueSyncQueue, QueueQuoteApproved, QueueInstallationSignoff, QueueWhatsApp}

// InitRabbitMQ establishes the first connection and starts the reconnect watcher.
func InitRabbitMQ(url string) error {
	brokerURL = url
	return connect()
}

// connect dials the broker, declares topology, publishes the globals, and starts
// a watcher that reconnects if the connection drops.
func connect() error {
	conn, err := amqp.Dial(brokerURL)
	if err != nil {
		return fmt.Errorf("failed to connect to rabbitmq: %w", err)
	}

	ch, err := conn.Channel()
	if err != nil {
		conn.Close()
		return fmt.Errorf("failed to open a channel: %w", err)
	}

	if err := declareTopology(ch); err != nil {
		conn.Close()
		return err
	}

	brokerMu.Lock()
	Conn = conn
	Channel = ch
	brokerMu.Unlock()

	logger.Log.Info("Connected to RabbitMQ successfully")
	go watchAndReconnect(conn)
	return nil
}

// declareTopology declares the dead-letter exchange/queue and every work queue
// with dead-lettering enabled.
//
// NOTE: a work queue that already exists WITHOUT the dead-letter argument (a
// deployment created before this change) will fail to redeclare here. Delete the
// old queues once so they can be recreated with the argument — in dev,
// `rabbitmqadmin delete queue name=<q>` or the management UI.
func declareTopology(ch *amqp.Channel) error {
	if err := ch.ExchangeDeclare(DeadLetterExchange, "fanout", true, false, false, false, nil); err != nil {
		return fmt.Errorf("failed to declare dead-letter exchange: %w", err)
	}
	if _, err := ch.QueueDeclare(QueueDeadLetter, true, false, false, false, nil); err != nil {
		return fmt.Errorf("failed to declare dead-letter queue: %w", err)
	}
	if err := ch.QueueBind(QueueDeadLetter, "", DeadLetterExchange, false, nil); err != nil {
		return fmt.Errorf("failed to bind dead-letter queue: %w", err)
	}

	args := amqp.Table{"x-dead-letter-exchange": DeadLetterExchange}
	for _, q := range workQueues {
		if _, err := ch.QueueDeclare(q, true, false, false, false, args); err != nil {
			return fmt.Errorf("failed to declare queue %s: %w", q, err)
		}
	}
	logger.Log.Info("RabbitMQ topology declared", "queues", workQueues, "dead_letter_queue", QueueDeadLetter)
	return nil
}

// watchAndReconnect blocks until conn closes. A graceful close (nil error) ends
// the watcher; an unexpected close retries connect() until it succeeds, which
// re-publishes the globals so supervised consumers can pick up the new
// connection (backend-bugs #14).
func watchAndReconnect(conn *amqp.Connection) {
	closeErr := <-conn.NotifyClose(make(chan *amqp.Error, 1))
	if closeErr == nil {
		return // graceful Close()
	}
	logger.Log.Warn("RabbitMQ connection lost, reconnecting...", "error", closeErr)
	for {
		time.Sleep(reconnectDelay)
		if err := connect(); err != nil {
			logger.Log.Warn("RabbitMQ reconnect attempt failed, retrying...", "error", err)
			continue
		}
		logger.Log.Info("RabbitMQ reconnected")
		return
	}
}

// Close gracefully shuts the current connection (which also closes its channel).
func Close() {
	brokerMu.Lock()
	defer brokerMu.Unlock()
	if Conn != nil && !Conn.IsClosed() {
		Conn.Close()
	}
}

// currentConn returns a live connection, reconnecting synchronously if the
// cached one is gone (e.g. a publish arrives before the watcher has recovered).
func currentConn() (*amqp.Connection, error) {
	brokerMu.Lock()
	conn := Conn
	brokerMu.Unlock()
	if conn != nil && !conn.IsClosed() {
		return conn, nil
	}
	if err := connect(); err != nil {
		return nil, err
	}
	brokerMu.Lock()
	conn = Conn
	brokerMu.Unlock()
	return conn, nil
}

// PublishEvent serializes the payload and publishes it durably to queueName. The
// message is persistent, the channel is in confirm mode, and the publish is
// retried across reconnects — so a broker restart no longer loses events, and a
// publish the broker never acknowledges is surfaced as an error rather than
// silently dropped (backend-bugs #14).
func PublishEvent(ctx context.Context, queueName string, payload interface{}) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal event payload: %w", err)
	}

	var lastErr error
	for attempt := 1; attempt <= maxPublishAttempts; attempt++ {
		if attempt > 1 {
			time.Sleep(reconnectDelay)
		}
		lastErr = publishConfirmed(ctx, queueName, body)
		if lastErr == nil {
			logger.Log.Info("Event published", "queue", queueName, "payload_size", len(body))
			return nil
		}
		logger.Log.Warn("Publish attempt failed", "queue", queueName, "attempt", attempt, "error", lastErr)
	}
	return fmt.Errorf("failed to publish to %s after %d attempts: %w", queueName, maxPublishAttempts, lastErr)
}

// publishConfirmed performs one publish on a fresh confirm-mode channel and waits
// for the broker's acknowledgement.
func publishConfirmed(ctx context.Context, queueName string, body []byte) error {
	conn, err := currentConn()
	if err != nil {
		return fmt.Errorf("broker unavailable: %w", err)
	}
	ch, err := conn.Channel()
	if err != nil {
		return fmt.Errorf("failed to open a channel: %w", err)
	}
	defer ch.Close()

	if err := ch.Confirm(false); err != nil {
		return fmt.Errorf("failed to put channel in confirm mode: %w", err)
	}
	confirms := ch.NotifyPublish(make(chan amqp.Confirmation, 1))

	if err := ch.PublishWithContext(ctx, "", queueName, false, false, amqp.Publishing{
		ContentType:  "application/json",
		DeliveryMode: amqp.Persistent, // survive a broker restart
		Body:         body,
	}); err != nil {
		return fmt.Errorf("publish failed: %w", err)
	}

	select {
	case c := <-confirms:
		if !c.Ack {
			return fmt.Errorf("broker nacked the publish")
		}
		return nil
	case <-time.After(publishConfirmWait):
		return fmt.Errorf("timed out waiting for publish confirmation")
	case <-ctx.Done():
		return ctx.Err()
	}
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
