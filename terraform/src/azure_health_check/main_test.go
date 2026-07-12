package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestHealthCheckTimerHandler(t *testing.T) {
	// Setup general mock environment variables
	os.Setenv("TELEGRAM_TOKEN", "")
	os.Setenv("TELEGRAM_CHAT_ID", "")
	os.Setenv("TARGET_URL", "https://httpbin.org/status/200")

	// 1. Set up mock Azure Blob Storage Server to maintain simulated state
	mockState := "UP"
	storageServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(State{LastState: mockState})
			return
		}
		if r.Method == http.MethodPut {
			var s State
			json.NewDecoder(r.Body).Decode(&s)
			mockState = s.LastState
			w.WriteHeader(http.StatusCreated)
			return
		}
	}))
	defer storageServer.Close()

	os.Setenv("AZURE_STORAGE_STATE_URL", storageServer.URL)

	// 2. Test transition from UP to UP (should pass, state remains UP, no alerts sent)
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
	if mockState != "UP" {
		t.Errorf("Expected mockState UP, got %s", mockState)
	}

	// 3. Test transition from UP to DOWN (status 500 failing check)
	os.Setenv("TARGET_URL", "https://httpbin.org/status/500")
	req, _ = http.NewRequest(http.MethodPost, "/healthCheckTimer", nil)
	rr = httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status code 200, got %d", rr.Code)
	}
	if mockState != "DOWN" {
		t.Errorf("Expected state to transition to DOWN, got %s", mockState)
	}

	// 4. Test transition from DOWN to DOWN (should remain DOWN without state mutation)
	req, _ = http.NewRequest(http.MethodPost, "/healthCheckTimer", nil)
	rr = httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status code 200, got %d", rr.Code)
	}
	if mockState != "DOWN" {
		t.Errorf("Expected state to remain DOWN, got %s", mockState)
	}

	// 5. Test transition from DOWN to UP (recovered status 200)
	os.Setenv("TARGET_URL", "https://httpbin.org/status/200")
	req, _ = http.NewRequest(http.MethodPost, "/healthCheckTimer", nil)
	rr = httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status code 200, got %d", rr.Code)
	}
	if mockState != "UP" {
		t.Errorf("Expected state to transition to UP, got %s", mockState)
	}
}
