package broker

// WhatsAppNotification is the RabbitMQ payload for sending template-based WhatsApp messages.
// It is published by the API container and consumed by the Worker container.
type WhatsAppNotification struct {
	Phone        string            `json:"phone"`         // E.164 format without '+' (e.g., "919876543210")
	TemplateName string            `json:"template_name"` // Pre-approved template name (e.g., "order_dispatched")
	Vars         map[string]string `json:"vars"`          // Dynamic variables injected into template body parameters
}
