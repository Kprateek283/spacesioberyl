package broker

import (
	"fmt"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

var Conn *amqp.Connection
var Channel *amqp.Channel

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
	return nil
}
