package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	fmt.Println("Worker container is running and waiting for tasks...")

	// Create a channel to listen for interrupt signals from Docker
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	// Block until a signal is received
	<-quit
	fmt.Println("Worker shutting down...")
}
