package logger

import (
	"io"
	"log/slog"
	"os"

	"gopkg.in/natefinch/lumberjack.v2"
)

// Log is the global logger instance
var Log *slog.Logger

// Init configures and initializes the global slog instance.
func Init() {
	// Configure log rolling using lumberjack
	fileWriter := &lumberjack.Logger{
		Filename:   "logs/system.log", // Path relative to the /app WORKDIR in Docker
		MaxSize:    10,                // Maximum size in megabytes before it rolls
		MaxBackups: 3,                 // Maximum number of old log files to retain
		MaxAge:     30,                // Maximum number of days to retain old log files
		Compress:   true,              // Compress rolled files to save space
	}

	// Write to both the console (so 'docker logs' still works) and the file
	multiWriter := io.MultiWriter(os.Stdout, fileWriter)

	// Configure the JSON handler
	handler := slog.NewJSONHandler(multiWriter, &slog.HandlerOptions{
		Level: slog.LevelInfo, 
	})

	// Set the package-level Log variable and the global default
	Log = slog.New(handler)
	slog.SetDefault(Log)
}
