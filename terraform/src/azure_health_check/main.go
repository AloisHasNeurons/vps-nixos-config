package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
)

// Azure Custom Handler InvokeResponse representation
type InvokeResponse struct {
	Outputs     map[string]interface{} `json:"Outputs"`
	Logs        []string               `json:"Logs"`
	ReturnValue interface{}            `json:"ReturnValue"`
}

type State struct {
	LastState string `json:"last_state"` // "UP" or "DOWN"
}

func main() {
	port := os.Getenv("FUNCTIONS_CUSTOMHANDLER_PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/healthCheckTimer", healthCheckTimerHandler)

	fmt.Printf("Starting Custom Handler on port %s...\n", port)
	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		fmt.Printf("Error starting server: %v\n", err)
	}
}

// 1. healthCheckTimerHandler is triggered by Azure Timer every 1 minute
// It pings the server, uses Azure Blob Storage to maintain state, and alerts on state transition
func healthCheckTimerHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	targetURL := os.Getenv("TARGET_URL")
	if targetURL == "" {
		writeResponse(w, http.StatusInternalServerError, "TARGET_URL env var is not set")
		return
	}

	client := http.Client{
		Timeout: 10 * time.Second,
	}

	// 1. Perform ping
	isUp := true
	reason := ""
	resp, err := client.Get(targetURL)
	if err != nil {
		isUp = false
		reason = fmt.Sprintf("Network connection failed: %v", err)
	} else {
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			isUp = false
			reason = fmt.Sprintf("Received non-200 HTTP status: %d", resp.StatusCode)
		}
	}

	currentState := "UP"
	if !isUp {
		currentState = "DOWN"
	}

	// 2. Fetch last state from storage blob using SAS token
	sasToken := os.Getenv("AZURE_STORAGE_SAS")
	storageAccount := os.Getenv("AZURE_STORAGE_ACCOUNT")
	stateURL := os.Getenv("AZURE_STORAGE_STATE_URL")

	if stateURL == "" && sasToken != "" && storageAccount != "" {
		stateURL = fmt.Sprintf("https://%s.blob.core.windows.net/function-releases/state.json%s", storageAccount, sasToken)
	}

	prevState := "UP"
	if stateURL != "" {
		prevState = getPreviousState(r.Context(), &client, stateURL)
	}

	// 3. Compare states and send alert on transition
	if currentState != prevState {
		telegramToken := os.Getenv("TELEGRAM_TOKEN")
		telegramChatID := os.Getenv("TELEGRAM_CHAT_ID")

		var message string
		if currentState == "DOWN" {
			message = fmt.Sprintf("🔴 <b>[Azure Monitor Alert]</b> Host is <b>DOWN</b>!\n\n<b>Target:</b> %s\n<b>Reason:</b> %s\n<b>Time:</b> %s",
				targetURL, reason, time.Now().Format("2006-01-02 15:04:05 MST"))
		} else {
			message = fmt.Sprintf("🟢 <b>[Azure Monitor Alert]</b> Host has <b>RECOVERED</b>!\n\n<b>Target:</b> %s\n<b>Time:</b> %s",
				targetURL, time.Now().Format("2006-01-02 15:04:05 MST"))
		}

		sendTelegramAlert(telegramToken, telegramChatID, message)

		// Save new state
		if stateURL != "" {
			saveState(r.Context(), &client, stateURL, currentState)
		}
	}

	if isUp {
		writeResponse(w, http.StatusOK, "Health check passed")
	} else {
		// Return 200 OK so Azure Functions host doesn't log internal platform failures
		// Since we handle stateful alerts inside Go, the Functions host can run successfully
		writeResponse(w, http.StatusOK, fmt.Sprintf("Health check failed: %s", reason))
	}
}

func getPreviousState(ctx context.Context, client *http.Client, stateURL string) string {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, stateURL, nil)
	if err != nil {
		fmt.Printf("[Azure State] Failed to create GET request: %v\n", err)
		return "UP"
	}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("[Azure State] GET request failed: %v\n", err)
		return "UP"
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		fmt.Printf("[Azure State] State file not found (404), defaulting to UP\n")
		return "UP" // First run, no state file yet
	}

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("[Azure State] GET returned non-200: %d\n", resp.StatusCode)
		return "UP"
	}

	var s State
	if err := json.NewDecoder(resp.Body).Decode(&s); err != nil {
		fmt.Printf("[Azure State] Failed to decode JSON: %v\n", err)
		return "UP"
	}
	fmt.Printf("[Azure State] Successfully loaded prevState: %s\n", s.LastState)
	return s.LastState
}

func saveState(ctx context.Context, client *http.Client, stateURL string, lastState string) {
	s := State{LastState: lastState}
	data, err := json.Marshal(s)
	if err != nil {
		fmt.Printf("[Azure State] Failed to marshal state: %v\n", err)
		return
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPut, stateURL, bytes.NewReader(data))
	if err != nil {
		fmt.Printf("[Azure State] Failed to create PUT request: %v\n", err)
		return
	}
	req.Header.Set("x-ms-blob-type", "BlockBlob")
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("[Azure State] PUT request failed: %v\n", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		fmt.Printf("[Azure State] PUT returned non-2xx status: %d\n", resp.StatusCode)
	} else {
		fmt.Printf("[Azure State] Successfully saved state %s\n", lastState)
	}
}

func writeResponse(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	response := InvokeResponse{
		ReturnValue: msg,
	}
	json.NewEncoder(w).Encode(response)
}

func sendTelegramAlert(token, chatID, message string) {
	if token == "" || chatID == "" {
		fmt.Printf("Alert trigger (skipping Telegram send - credentials missing): %s\n", message)
		return
	}

	apiURL := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", token)
	payload := map[string]string{
		"chat_id":    chatID,
		"text":       message,
		"parse_mode": "HTML",
	}
	jsonPayload, _ := json.Marshal(payload)

	resp, err := http.Post(apiURL, "application/json", bytes.NewBuffer(jsonPayload))
	if err != nil {
		fmt.Printf("Failed to send Telegram alert: %v\n", err)
		return
	}
	defer resp.Body.Close()
}
