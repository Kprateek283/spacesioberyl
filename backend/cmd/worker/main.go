package main

import (
	"os"
	"os/signal"
	"syscall"

	"github.com/spacesioberyl/system-v1/internal/logger"
)

func main() {
	logger.Init()
	logger.Log.Info("Worker container is running and waiting for tasks...")

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	<-quit
	logger.Log.Info("Worker shutting down gracefully...")
}
