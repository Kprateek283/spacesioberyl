package config

import (
	"os"
)

// Config holds all the environment variables for the application
type Config struct {
	APIPort     string
	DatabaseURL string
	RedisURL    string
	RabbitMQURL string
}

// Load reads environment variables and returns a populated Config struct.
// It uses fallback values just in case the .env file is missing.
func Load() *Config {
	return &Config{
		APIPort:     getEnv("API_PORT", "8080"),
		DatabaseURL: getEnv("DATABASE_URL", "postgres://admin:securepassword@system_db:5432/erp_v1?sslmode=disable"),
		RedisURL:    getEnv("REDIS_URL", "redis://system_cache:6379/0"),
		RabbitMQURL: getEnv("RABBITMQ_URL", "amqp://guest:guest@system_mq:5672/"),
	}
}

// getEnv is a helper function to read an environment variable or return a default value
func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
