package main

import (
	"fmt"
	"net/http"
)

func main() {
	fmt.Println("API container is running on port 8080...")
	// Starts a dummy web server to keep the container alive
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Println("Server failed:", err)
	}
}
