package main

import (
	"bytes"
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

// Azure Common Alert Schema structure
type AzureCommonAlert struct {
	SchemaId string `json:"schemaId"`
	Data     struct {
		Essentials struct {
			AlertRule        string `json:"alertRule"`
			MonitorCondition string `json:"monitorCondition"` // "Fired" or "Resolved"
			Description      string `json:"description"`
		} `json:"essentials"`
	} `json:"data"`
}

func main() {
	port := os.Getenv("FUNCTIONS_CUSTOMHANDLER_PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/healthCheckTimer", healthCheckTimerHandler)
	http.HandleFunc("/alertHandler", alertHandler)

	fmt.Printf("Starting Custom Handler on port %s...\n", port)
	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		fmt.Printf("Error starting server: %v\n", err)
	}
}

// 1. healthCheckTimerHandler is triggered by Azure Timer every 1 minute
// It pings the server and returns 500 on failure, incrementing the Http5xx metric
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

	resp, err := client.Get(targetURL)
	if err != nil {
		fmt.Printf("Health check failed for %s: %v\n", targetURL, err)
		writeResponse(w, http.StatusInternalServerError, fmt.Sprintf("Health check failed: %v", err))
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("Health check returned non-200 code: %d for %s\n", resp.StatusCode, targetURL)
		writeResponse(w, http.StatusInternalServerError, fmt.Sprintf("Health check failed with status code: %d", resp.StatusCode))
		return
	}

	writeResponse(w, http.StatusOK, "Health check passed")
}

// 2. alertHandler is triggered by Azure Action Group Webhook when the Alert Fires or Resolves
func alertHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	var alert AzureCommonAlert
	err := json.NewDecoder(r.Body).Decode(&alert)
	if err != nil {
		fmt.Printf("Failed to decode Azure Alert payload: %v\n", err)
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	telegramToken := os.Getenv("TELEGRAM_TOKEN")
	telegramChatID := os.Getenv("TELEGRAM_CHAT_ID")
	targetURL := os.Getenv("TARGET_URL")

	var text string
	if alert.Data.Essentials.MonitorCondition == "Fired" {
		text = fmt.Sprintf("🔴 <b>[Azure Monitor Alert]</b> Host is <b>DOWN</b>!\n\n<b>Target:</b> %s\n<b>Reason:</b> %s\n<b>Time:</b> %s",
			targetURL, alert.Data.Essentials.Description, time.Now().Format("2006-01-02 15:04:05 MST"))
	} else if alert.Data.Essentials.MonitorCondition == "Resolved" {
		text = fmt.Sprintf("🟢 <b>[Azure Monitor Alert]</b> Host has <b>RECOVERED</b>!\n\n<b>Target:</b> %s\n<b>Time:</b> %s",
			targetURL, time.Now().Format("2006-01-02 15:04:05 MST"))
	} else {
		text = fmt.Sprintf("ℹ️ [Azure Monitor] Alert state changed to %s for %s", alert.Data.Essentials.MonitorCondition, alert.Data.Essentials.AlertRule)
	}

	sendTelegramAlert(telegramToken, telegramChatID, text)
	w.WriteHeader(http.StatusOK)
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
