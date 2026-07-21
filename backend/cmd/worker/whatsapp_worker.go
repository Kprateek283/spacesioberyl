package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sort"
	"time"

	"github.com/spacesioberyl/system-v1/internal/broker"
	"github.com/spacesioberyl/system-v1/internal/config"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

// consumeWhatsApp consumes from the whatsapp_queue and processes each message by
// calling the Meta WhatsApp Cloud API. The "is WhatsApp configured" guard lives
// at the call site so a disabled integration is not supervised into a restart
// loop. Returns when the delivery channel closes so the supervisor can restart it.
func consumeWhatsApp(cfg *config.Config) error {
	ch, err := broker.Conn.Channel()
	if err != nil {
		return fmt.Errorf("open channel: %w", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume(broker.QueueWhatsApp, "worker-whatsapp", true, false, false, false, nil)
	if err != nil {
		return fmt.Errorf("start consuming: %w", err)
	}

	logger.Log.Info("Consumer started", "queue", broker.QueueWhatsApp)

	for msg := range msgs {
		var notif broker.WhatsAppNotification
		if err := json.Unmarshal(msg.Body, &notif); err != nil {
			logger.Log.Error("WhatsApp: failed to unmarshal message", "error", err, "body", string(msg.Body))
			continue
		}

		logger.Log.Info("WhatsApp: processing notification",
			"phone", notif.Phone, "template", notif.TemplateName, "vars_count", len(notif.Vars))

		if err := sendWhatsAppTemplate(cfg, notif); err != nil {
			logger.Log.Error("WhatsApp: failed to send template message",
				"phone", notif.Phone, "template", notif.TemplateName, "error", err)
		} else {
			logger.Log.Info("✅ WhatsApp: template message sent successfully",
				"phone", notif.Phone, "template", notif.TemplateName)
		}
	}
	return nil // delivery channel closed → supervisor restarts
}

// sendWhatsAppTemplate constructs the Meta Cloud API payload and POSTs it.
// It returns an error if the API returns a non-200 status or the request fails.
func sendWhatsAppTemplate(cfg *config.Config, notif broker.WhatsAppNotification) error {
	url := fmt.Sprintf("https://graph.facebook.com/v19.0/%s/messages", cfg.WhatsAppPhoneID)

	// Build the body parameters from the vars map.
	// Sort keys for deterministic ordering (alphabetical → positional mapping).
	keys := make([]string, 0, len(notif.Vars))
	for k := range notif.Vars {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var bodyParams []map[string]string
	for _, k := range keys {
		bodyParams = append(bodyParams, map[string]string{
			"type": "text",
			"text": notif.Vars[k],
		})
	}

	// Build the WhatsApp template message payload per Meta API spec
	payload := map[string]interface{}{
		"messaging_product": "whatsapp",
		"to":                notif.Phone,
		"type":              "template",
		"template": map[string]interface{}{
			"name": notif.TemplateName,
			"language": map[string]string{
				"code": "en",
			},
			"components": []map[string]interface{}{
				{
					"type":       "body",
					"parameters": bodyParams,
				},
			},
		},
	}

	jsonBody, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal WhatsApp payload: %w", err)
	}

	// Create the HTTP request
	req, err := http.NewRequest("POST", url, bytes.NewReader(jsonBody))
	if err != nil {
		return fmt.Errorf("failed to create HTTP request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+cfg.WhatsAppToken)

	// Send the request with a timeout
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("HTTP request to Meta API failed: %w", err)
	}
	defer resp.Body.Close()

	// Read and log the response
	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode != http.StatusOK {
		// Log the full error response so it shows up in `docker logs system_worker`
		logger.Log.Error("WhatsApp: Meta API rejected the message",
			"status_code", resp.StatusCode,
			"response_body", string(respBody),
			"phone", notif.Phone,
			"template", notif.TemplateName,
		)
		return fmt.Errorf("meta API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	return nil
}
