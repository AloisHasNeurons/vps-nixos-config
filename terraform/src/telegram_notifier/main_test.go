package main

import (
	"context"
	"encoding/json"
	"os"
	"testing"

	"github.com/aws/aws-lambda-go/events"
)

func TestHandler(t *testing.T) {
	os.Setenv("TELEGRAM_TOKEN", "")
	os.Setenv("TELEGRAM_CHAT_ID", "")
	os.Setenv("TARGET_URL", "https://crapadouille.fr")

	// Mock SNS CloudWatch Alarm Message (Failing state)
	alarmMsg := CloudWatchAlarmMessage{
		AlarmName:      "vps-health-check-alarm",
		NewStateValue:  "ALARM",
		NewStateReason: "Threshold Crossed: 1 out of 1 datapoints were greater than or equal to threshold 1.0",
		OldStateValue:  "OK",
	}

	alarmJson, err := json.Marshal(alarmMsg)
	if err != nil {
		t.Fatal(err)
	}

	// Wrap in SNS event record
	snsEvent := events.SNSEvent{
		Records: []events.SNSEventRecord{
			{
				SNS: events.SNSEntity{
					Message: string(alarmJson),
				},
			},
		},
	}

	// Execute handler
	err = handler(context.Background(), snsEvent)
	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}

	// Mock SNS CloudWatch Alarm Message (Recovery state)
	recoveryMsg := CloudWatchAlarmMessage{
		AlarmName:      "vps-health-check-alarm",
		NewStateValue:  "OK",
		NewStateReason: "Threshold Crossed: 0 out of 1 datapoints were greater than or equal to threshold 1.0",
		OldStateValue:  "ALARM",
	}

	recoveryJson, _ := json.Marshal(recoveryMsg)
	snsEvent.Records[0].SNS.Message = string(recoveryJson)

	err = handler(context.Background(), snsEvent)
	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}
}
