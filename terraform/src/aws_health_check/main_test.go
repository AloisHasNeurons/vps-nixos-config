package main

import (
	"context"
	"os"
	"testing"
)

func TestHandler(t *testing.T) {
	// 1. Test passing check (HTTP 200)
	os.Setenv("TARGET_URL", "https://httpbin.org/status/200")
	
	resp, err := handler(context.Background())
	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}

	if resp.Message != "Health check passed" {
		t.Errorf("Expected 'Health check passed', got '%s'", resp.Message)
	}

	// 2. Test failing check (HTTP 500)
	os.Setenv("TARGET_URL", "https://httpbin.org/status/500")
	
	resp, err = handler(context.Background())
	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}

	expectedMsg := "Health check failed with status code: 500"
	if resp.Message != expectedMsg {
		t.Errorf("Expected '%s', got '%s'", expectedMsg, resp.Message)
	}
}
