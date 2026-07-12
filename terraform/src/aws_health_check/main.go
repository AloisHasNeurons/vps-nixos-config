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
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"github.com/aws/aws-sdk-go-v2/service/ssm/types"
)

type Response struct {
	Message string `json:"message"`
}

type SSMAPI interface {
	GetParameter(ctx context.Context, params *ssm.GetParameterInput, optFns ...func(*ssm.Options)) (*ssm.GetParameterOutput, error)
	PutParameter(ctx context.Context, params *ssm.PutParameterInput, optFns ...func(*ssm.Options)) (*ssm.PutParameterOutput, error)
}

var ssmClient SSMAPI

func handler(ctx context.Context) (Response, error) {
	targetURL := os.Getenv("TARGET_URL")
	if targetURL == "" {
		return Response{Message: "TARGET_URL is not set"}, fmt.Errorf("TARGET_URL is not set")
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

	// 2. Load AWS config and SSM Client
	if ssmClient == nil {
		cfg, err := config.LoadDefaultConfig(ctx)
		if err != nil {
			return Response{Message: "Failed to load AWS config"}, fmt.Errorf("failed to load AWS config: %v", err)
		}
		ssmClient = ssm.NewFromConfig(cfg)
	}

	paramName := "/vps/health-check/state"
	prevState := getPreviousState(ctx, ssmClient, paramName)

	// 3. Compare states and send alert on transition
	if currentState != prevState {
		telegramToken := os.Getenv("TELEGRAM_TOKEN")
		telegramChatID := os.Getenv("TELEGRAM_CHAT_ID")

		var message string
		if currentState == "DOWN" {
			message = fmt.Sprintf("🔴 <b>[AWS Monitor Alert]</b> Host is <b>DOWN</b>!\n\n<b>Target:</b> %s\n<b>Reason:</b> %s\n<b>Time:</b> %s",
				targetURL, reason, time.Now().Format("2006-01-02 15:04:05 MST"))
		} else {
			message = fmt.Sprintf("🟢 <b>[AWS Monitor Alert]</b> Host has <b>RECOVERED</b>!\n\n<b>Target:</b> %s\n<b>Time:</b> %s",
				targetURL, time.Now().Format("2006-01-02 15:04:05 MST"))
		}

		sendTelegramAlert(telegramToken, telegramChatID, message)
		saveState(ctx, ssmClient, paramName, currentState)
	}

	if isUp {
		return Response{Message: "Health check passed"}, nil
	}
	return Response{Message: fmt.Sprintf("Health check failed: %s", reason)}, nil
}

func getPreviousState(ctx context.Context, client SSMAPI, paramName string) string {
	out, err := client.GetParameter(ctx, &ssm.GetParameterInput{
		Name: &paramName,
	})
	if err != nil {
		return "UP" // Default to UP on first run or missing parameter
	}
	return *out.Parameter.Value
}

func saveState(ctx context.Context, client SSMAPI, paramName, val string) {
	overwrite := true
	_, _ = client.PutParameter(ctx, &ssm.PutParameterInput{
		Name:      &paramName,
		Value:     &val,
		Type:      types.ParameterTypeString,
		Overwrite: &overwrite,
	})
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

func main() {
	lambda.Start(handler)
}
