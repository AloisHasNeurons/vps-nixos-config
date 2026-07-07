package main

import (
	"bytes"
	"context"
	"encoding/json"
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
	telegramToken := os.Getenv("TELEGRAM_TOKEN")
	telegramChatID := os.Getenv("TELEGRAM_CHAT_ID")

	if targetURL == "" {
		return Response{Message: "TARGET_URL env var is not set"}, nil
	}

	client := http.Client{
		Timeout: 10 * time.Second,
	}

	// Perform health check probe
	resp, err := client.Get(targetURL)
	if err != nil {
		sendTelegramAlert(telegramToken, telegramChatID, fmt.Sprintf("⚠️ <b>[AWS Monitoring]</b> Health check failed for %s:\n<code>%v</code>", targetURL, err))
		return Response{Message: fmt.Sprintf("Health check failed: %v", err)}, nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		sendTelegramAlert(telegramToken, telegramChatID, fmt.Sprintf("⚠️ <b>[AWS Monitoring]</b> Health check returned non-200 status code: <b>%d</b> for %s", resp.StatusCode, targetURL))
		return Response{Message: fmt.Sprintf("Health check failed with status code: %d", resp.StatusCode)}, nil
	}

	return Response{Message: "Health check passed"}, nil
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

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("Telegram API returned non-200: %d\n", resp.StatusCode)
	}
}

func main() {
	lambda.Start(handler)
}
