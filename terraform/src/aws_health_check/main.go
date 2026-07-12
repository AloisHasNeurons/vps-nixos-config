package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
)

type Response struct {
	Message string `json:"message"`
}

func handler(ctx context.Context) (Response, error) {
	targetURL := os.Getenv("TARGET_URL")

	if targetURL == "" {
		return Response{Message: "TARGET_URL env var is not set"}, fmt.Errorf("TARGET_URL env var is not set")
	}

	client := http.Client{
		Timeout: 10 * time.Second,
	}

	// Perform health check probe
	resp, err := client.Get(targetURL)
	if err != nil {
		return Response{Message: fmt.Sprintf("Health check failed: %v", err)}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return Response{Message: fmt.Sprintf("Health check failed with status code: %d", resp.StatusCode)}, fmt.Errorf("HTTP status: %d", resp.StatusCode)
	}

	return Response{Message: "Health check passed"}, nil
}

func main() {
	lambda.Start(handler)
}
