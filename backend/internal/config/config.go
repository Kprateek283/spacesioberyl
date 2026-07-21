package config

import (
	"fmt"
	"os"
	"strings"
)

// MinJWTSecretLen is the minimum accepted JWT signing key length. HS256 keys
// shorter than 32 bytes weaken the signature meaningfully, so we refuse to boot
// rather than sign forgeable tokens.
const MinJWTSecretLen = 32

// Config holds all the environment variables for the application
type Config struct {
	APIPort     string
	DatabaseURL string
	RedisURL    string
	RabbitMQURL string
	JWTSecret   string

	// AppEnv gates development-only behaviour (e.g. printing password-reset OTPs
	// to stdout). Anything other than "production" is treated as non-production.
	AppEnv string

	// CORSAllowedOrigins is the production allow-list, from a comma-separated
	// CORS_ALLOWED_ORIGINS. Local development origins are always allowed on top
	// of these (see middleware.CORS).
	CORSAllowedOrigins []string

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
		APIPort: getEnv("API_PORT", "8080"),
		// Secrets have no defaults — an unset secret must fail loudly at boot,
		// never silently fall back to a well-known credential (backend-bugs #25).
		DatabaseURL: getEnv("DATABASE_URL", ""),
		RedisURL:    getEnv("REDIS_URL", "redis://system_cache:6379/0"),
		RabbitMQURL: getEnv("RABBITMQ_URL", "amqp://guest:guest@system_mq:5672/"),
		JWTSecret:   getEnv("JWT_SECRET", ""),

		AppEnv:             getEnv("APP_ENV", "development"),
		CORSAllowedOrigins: splitAndTrim(getEnv("CORS_ALLOWED_ORIGINS", "")),

		OfficeIP: getEnv("OFFICE_IP", "0.0.0.0"), // 0.0.0.0 = dev mode (all IPs accepted)

		MinIOEndpoint:  getEnv("MINIO_ENDPOINT", "system_storage:9000"),
		MinIOAccessKey: getEnv("MINIO_ACCESS_KEY", ""),
		MinIOSecretKey: getEnv("MINIO_SECRET_KEY", ""),
		MinIOBucket:    getEnv("MINIO_BUCKET", "crm-files"),
		MinIOUseSSL:    getEnv("MINIO_USE_SSL", "false") == "true",
		MinIOPublicURL: getEnv("MINIO_PUBLIC_URL", "http://localhost:9000"),

		WhatsAppToken:             getEnv("WHATSAPP_TOKEN", ""),
		WhatsAppPhoneID:           getEnv("WHATSAPP_PHONE_ID", ""),
		WhatsAppTemplateNamespace: getEnv("WHATSAPP_TEMPLATE_NAMESPACE", ""),
	}
}

// Validate rejects configurations that would start the API in an unsafe state.
func (c *Config) Validate() error {
	if c.JWTSecret == "" {
		return fmt.Errorf("JWT_SECRET is not set: refusing to start, as every token would be signed with an empty key")
	}
	if len(c.JWTSecret) < MinJWTSecretLen {
		return fmt.Errorf("JWT_SECRET is %d bytes, minimum is %d: refusing to start with a weak signing key", len(c.JWTSecret), MinJWTSecretLen)
	}
	// Secrets must be supplied explicitly — no fallback to a shipped credential.
	if c.DatabaseURL == "" {
		return fmt.Errorf("DATABASE_URL is not set: refusing to start without database credentials")
	}
	if c.MinIOAccessKey == "" || c.MinIOSecretKey == "" {
		return fmt.Errorf("MINIO_ACCESS_KEY / MINIO_SECRET_KEY are not set: refusing to start without object-storage credentials")
	}
	return nil
}

// getEnv is a helper function to read an environment variable or return a default value
func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}

// splitAndTrim turns a comma-separated env value into a trimmed, non-empty slice.
func splitAndTrim(csv string) []string {
	var out []string
	for _, part := range strings.Split(csv, ",") {
		if p := strings.TrimSpace(part); p != "" {
			out = append(out, p)
		}
	}
	return out
}
