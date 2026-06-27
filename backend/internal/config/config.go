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
	JWTSecret   string

	// Office Network IP (for attendance WiFi check)
	OfficeIP string

	// MinIO (S3-compatible object storage)
	MinIOEndpoint  string
	MinIOAccessKey string
	MinIOSecretKey string
	MinIOBucket    string
	MinIOUseSSL    bool
	MinIOPublicURL string

	// WhatsApp (Meta Cloud API)
	WhatsAppToken              string
	WhatsAppPhoneID            string
	WhatsAppTemplateNamespace  string
}

// Load reads environment variables and returns a populated Config struct.
// It uses fallback values just in case the .env file is missing.
func Load() *Config {
	return &Config{
		APIPort:     getEnv("API_PORT", "8080"),
		DatabaseURL: getEnv("DATABASE_URL", "postgres://admin:securepassword@system_db:5432/erp_v1?sslmode=disable"),
		RedisURL:    getEnv("REDIS_URL", "redis://system_cache:6379/0"),
		RabbitMQURL: getEnv("RABBITMQ_URL", "amqp://guest:guest@system_mq:5672/"),
		JWTSecret:   getEnv("JWT_SECRET", ""),

		OfficeIP: getEnv("OFFICE_IP", "0.0.0.0"), // 0.0.0.0 = dev mode (all IPs accepted)

		MinIOEndpoint:  getEnv("MINIO_ENDPOINT", "system_storage:9000"),
		MinIOAccessKey: getEnv("MINIO_ACCESS_KEY", "admin"),
		MinIOSecretKey: getEnv("MINIO_SECRET_KEY", "securepassword"),
		MinIOBucket:    getEnv("MINIO_BUCKET", "crm-files"),
		MinIOUseSSL:    getEnv("MINIO_USE_SSL", "false") == "true",
		MinIOPublicURL: getEnv("MINIO_PUBLIC_URL", "http://localhost:9000"),

		WhatsAppToken:             getEnv("WHATSAPP_TOKEN", ""),
		WhatsAppPhoneID:           getEnv("WHATSAPP_PHONE_ID", ""),
		WhatsAppTemplateNamespace: getEnv("WHATSAPP_TEMPLATE_NAMESPACE", ""),
	}
}

// getEnv is a helper function to read an environment variable or return a default value
func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
