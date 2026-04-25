package cache

import (
	"context"
	"fmt"

	"github.com/redis/go-redis/v9"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

var Client *redis.Client

func InitRedis(ctx context.Context, url string) error {
	opts, err := redis.ParseURL(url)
	if err != nil {
		return fmt.Errorf("failed to parse redis URL: %w", err)
	}

	client := redis.NewClient(opts)

	// Verify the cache is alive
	if err := client.Ping(ctx).Err(); err != nil {
		return fmt.Errorf("redis ping failed: %w", err)
	}

	Client = client
	logger.Log.Info("Connected to Redis successfully")
	return nil
}
