package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestHealthCheckHandler(t *testing.T) {
	// 1. Test passing check (HTTP 200)
	os.Setenv("TARGET_URL", "https://httpbin.org/status/200")
	
	req, err := http.NewRequest(http.MethodPost, "/healthCheckTimer", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(healthCheckHandler)
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status code 200, got %d", rr.Code)
	}

	var response InvokeResponse
	err = json.Unmarshal(rr.Body.Bytes(), &response)
	if err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response.ReturnValue != "Health check passed" {
		t.Errorf("Expected 'Health check passed', got '%v'", response.ReturnValue)
	}

	// 2. Test failing check (HTTP 500)
	os.Setenv("TARGET_URL", "https://httpbin.org/status/500")
	
	req, err = http.NewRequest(http.MethodPost, "/healthCheckTimer", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr = httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	var errorResponse InvokeResponse
	json.Unmarshal(rr.Body.Bytes(), &errorResponse)
	
	expectedMsg := "Health check failed with status code: 500"
	if errorResponse.ReturnValue != expectedMsg {
		t.Errorf("Expected '%s', got '%v'", expectedMsg, errorResponse.ReturnValue)
	}
}
