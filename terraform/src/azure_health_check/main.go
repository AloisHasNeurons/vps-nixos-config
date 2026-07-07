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

func main() {
	port := os.Getenv("FUNCTIONS_CUSTOMHANDLER_PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/healthCheckTimer", healthCheckHandler)

	fmt.Printf("Starting Custom Handler on port %s...\n", port)
	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		fmt.Printf("Error starting server: %v\n", err)
	}
}

func healthCheckHandler(w http.ResponseWriter, r *http.Request) {
	// Azure Custom Handlers receive POST requests from the Functions Host
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	targetURL := os.Getenv("TARGET_URL")
	telegramToken := os.Getenv("TELEGRAM_TOKEN")
	telegramChatID := os.Getenv("TELEGRAM_CHAT_ID")

	if targetURL == "" {
		writeResponse(w, "TARGET_URL env var is not set")
		return
	}

	client := http.Client{
		Timeout: 10 * time.Second,
	}

	resp, err := client.Get(targetURL)
	if err != nil {
		sendTelegramAlert(telegramToken, telegramChatID, fmt.Sprintf("⚠️ <b>[Azure Monitoring]</b> Health check failed for %s:\n<code>%v</code>", targetURL, err))
		writeResponse(w, fmt.Sprintf("Health check failed: %v", err))
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		sendTelegramAlert(telegramToken, telegramChatID, fmt.Sprintf("⚠️ <b>[Azure Monitoring]</b> Health check returned non-200 status code: <b>%d</b> for %s", resp.StatusCode, targetURL))
		writeResponse(w, fmt.Sprintf("Health check failed with status code: %d", resp.StatusCode))
		return
	}

	writeResponse(w, "Health check passed")
}

func writeResponse(w http.ResponseWriter, msg string) {
	w.Header().Set("Content-Type", "application/json")
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
