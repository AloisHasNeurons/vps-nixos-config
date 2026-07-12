package main

import (
	"context"
	"os"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"github.com/aws/aws-sdk-go-v2/service/ssm/types"
)

type mockSSM struct {
	state string
}

func (m *mockSSM) GetParameter(ctx context.Context, params *ssm.GetParameterInput, optFns ...func(*ssm.Options)) (*ssm.GetParameterOutput, error) {
	return &ssm.GetParameterOutput{
		Parameter: &types.Parameter{
			Value: &m.state,
		},
	}, nil
}

func (m *mockSSM) PutParameter(ctx context.Context, params *ssm.PutParameterInput, optFns ...func(*ssm.Options)) (*ssm.PutParameterOutput, error) {
	m.state = *params.Value
	return &ssm.PutParameterOutput{}, nil
}

func TestHandler(t *testing.T) {
	os.Setenv("TELEGRAM_TOKEN", "")
	os.Setenv("TELEGRAM_CHAT_ID", "")
	os.Setenv("TARGET_URL", "https://httpbin.org/status/200")

	// Inject mock SSM client
	mock := &mockSSM{state: "UP"}
	ssmClient = mock

	// 1. Transition UP to UP (should pass, remains UP)
	resp, err := handler(context.Background())
	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}
	if resp.Message != "Health check passed" {
		t.Errorf("Expected 'Health check passed', got '%s'", resp.Message)
	}
	if mock.state != "UP" {
		t.Errorf("Expected state UP, got %s", mock.state)
	}

	// 2. Transition UP to DOWN (status 500)
	os.Setenv("TARGET_URL", "https://httpbin.org/status/500")
	resp, err = handler(context.Background())
	if err != nil {
		t.Fatalf("Expected no execution error, got %v", err)
	}
	if !strings.Contains(resp.Message, "Health check failed") {
		t.Errorf("Expected message to contain 'Health check failed', got '%s'", resp.Message)
	}
	if mock.state != "DOWN" {
		t.Errorf("Expected state to transition to DOWN, got %s", mock.state)
	}

	// 3. Transition DOWN to DOWN (should remain DOWN)
	resp, err = handler(context.Background())
	if err != nil {
		t.Fatalf("Expected no execution error, got %v", err)
	}
	if !strings.Contains(resp.Message, "Health check failed") {
		t.Errorf("Expected message to contain 'Health check failed', got '%s'", resp.Message)
	}
	if mock.state != "DOWN" {
		t.Errorf("Expected state to remain DOWN, got %s", mock.state)
	}

	// 4. Transition DOWN to UP (recovered status 200)
	os.Setenv("TARGET_URL", "https://httpbin.org/status/200")
	resp, err = handler(context.Background())
	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}
	if mock.state != "UP" {
		t.Errorf("Expected state to transition to UP, got %s", mock.state)
	}
}
