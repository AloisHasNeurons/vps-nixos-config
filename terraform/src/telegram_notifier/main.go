package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type CloudWatchAlarmMessage struct {
	AlarmName      string `json:"AlarmName"`
	NewStateValue  string `json:"NewStateValue"`
	NewStateReason string `json:"NewStateReason"`
	OldStateValue  string `json:"OldStateValue"`
}

func handler(ctx context.Context, snsEvent events.SNSEvent) error {
	telegramToken := os.Getenv("TELEGRAM_TOKEN")
	telegramChatID := os.Getenv("TELEGRAM_CHAT_ID")
	targetURL := os.Getenv("TARGET_URL")

	for _, record := range snsEvent.Records {
		snsMsg := record.SNS.Message
		var alarm CloudWatchAlarmMessage
		err := json.Unmarshal([]byte(snsMsg), &alarm)
		if err != nil {
			fmt.Printf("Failed to unmarshal SNS message: %v\n", err)
			continue
		}

		var text string
		if alarm.NewStateValue == "ALARM" {
			text = fmt.Sprintf("🔴 <b>[AWS Monitor Alert]</b> Host is <b>DOWN</b>!\n\n<b>Target:</b> %s\n<b>Reason:</b> %s\n<b>Time:</b> %s",
				targetURL, alarm.NewStateReason, time.Now().Format("2006-01-02 15:04:05 MST"))
		} else if alarm.NewStateValue == "OK" {
			text = fmt.Sprintf("🟢 <b>[AWS Monitor Alert]</b> Host has <b>RECOVERED</b>!\n\n<b>Target:</b> %s\n<b>Time:</b> %s",
				targetURL, time.Now().Format("2006-01-02 15:04:05 MST"))
		} else {
			text = fmt.Sprintf("ℹ️ [AWS Monitor] Alarm state changed to %s for %s", alarm.NewStateValue, alarm.AlarmName)
		}

		sendTelegramAlert(telegramToken, telegramChatID, text)
	}

	return nil
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
