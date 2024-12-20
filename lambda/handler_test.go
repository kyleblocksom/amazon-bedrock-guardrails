package main

import (
	"context"
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
)

func TestParseStateChangeTime(t *testing.T) {
	v := "2024-12-03T00:34:33.918+0000"
	_, err := time.Parse("2006-01-02T15:04:05.000-0700", v)
	if err != nil {
		t.Errorf("unable to parse: %v", err)
	}
}

func TestSummarize(t *testing.T) {
	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithSharedConfigProfile("bedrock-guardrails-cw-metrics"))
	if err != nil {
		t.Fatalf("expect error to be nil but got: '%s'", err)
	}
	bc := bedrockruntime.NewFromConfig(cfg)

	alarm, events, err := readTestFixture()
	if err != nil {
		t.Fatalf("expect error to be nil but got: '%s'", err)
	}
	res, err := Summarize(ctx, bc, *alarm, events)
	if err != nil {
		t.Fatalf("expect error to be nil but got: '%s'", err)
	}
	t.Logf("Response: %s", res)
}

type messagesFixture struct {
	Data []*ModelInvocationLog
}

func readTestFixture() (*events.CloudWatchAlarmSNSPayload, []*ModelInvocationLog, error) {
	ab, err := os.ReadFile("./fixtures/alarm.json")
	if err != nil {
		return nil, nil, err
	}
	a := &events.CloudWatchAlarmSNSPayload{}
	if err := json.Unmarshal(ab, a); err != nil {
		return nil, nil, err
	}
	bb, err := os.ReadFile("./fixtures/messages.json")
	if err != nil {
		return nil, nil, err
	}
	b := &messagesFixture{}
	if err := json.Unmarshal(bb, b); err != nil {
		return nil, nil, err
	}
	return a, b.Data, nil
}
