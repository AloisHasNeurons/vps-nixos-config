package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestHealthCheckTimerHandler(t *testing.T) {
	// 1. Test passing check (HTTP 200)
	os.Setenv("TARGET_URL", "https://httpbin.org/status/200")

	req, err := http.NewRequest(http.MethodPost, "/healthCheckTimer", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(healthCheckTimerHandler)
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

	if rr.Code != http.StatusInternalServerError {
		t.Errorf("Expected status code 500, got %d", rr.Code)
	}

	var errorResponse InvokeResponse
	json.Unmarshal(rr.Body.Bytes(), &errorResponse)

	expectedMsg := "Health check failed with status code: 500"
	if errorResponse.ReturnValue != expectedMsg {
		t.Errorf("Expected '%s', got '%v'", expectedMsg, errorResponse.ReturnValue)
	}
}

func TestAlertHandler(t *testing.T) {
	os.Setenv("TELEGRAM_TOKEN", "")
	os.Setenv("TELEGRAM_CHAT_ID", "")
	os.Setenv("TARGET_URL", "https://crapadouille.fr")

	// Mock Fired alert payload
	firedPayload := `{
		"schemaId": "azureMonitorCommonAlertSchema",
		"data": {
			"essentials": {
				"alertRule": "vps-health-check-alert",
				"monitorCondition": "Fired",
				"description": "VPS is down"
			}
		}
	}`

	req, err := http.NewRequest(http.MethodPost, "/alertHandler", bytes.NewBufferString(firedPayload))
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(alertHandler)
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status code 200, got %d", rr.Code)
	}

	// Mock Resolved alert payload
	resolvedPayload := `{
		"schemaId": "azureMonitorCommonAlertSchema",
		"data": {
			"essentials": {
				"alertRule": "vps-health-check-alert",
				"monitorCondition": "Resolved",
				"description": "VPS is up"
			}
		}
	}`

	req, err = http.NewRequest(http.MethodPost, "/alertHandler", bytes.NewBufferString(resolvedPayload))
	if err != nil {
		t.Fatal(err)
	}

	rr = httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status code 200, got %d", rr.Code)
	}
}
