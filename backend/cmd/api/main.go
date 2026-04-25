package main

import (
	"net/http"
	"os"

	"github.com/spacesioberyl/system-v1/internal/logger"
)

func main() {
	logger.Init()
	logger.Log.Info("Starting API container", "port", "8080")

	if err := http.ListenAndServe(":8080", nil); err != nil {
		logger.Log.Error("Server failed", "error", err.Error())
		os.Exit(1)
	}
}
