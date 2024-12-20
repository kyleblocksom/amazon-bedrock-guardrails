package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatchlogs"
)

func main() {
	if err := run(); err != nil {
		_, err := os.Stderr.WriteString(err.Error())
		if err != nil {
			fmt.Println(err.Error())
		}
		os.Exit(2)
	}
}

func run() error {
	var ops = []func(*config.LoadOptions) error{
		config.WithSharedConfigProfile("bedrock-guardrails-cw-metrics"),
		config.WithDefaultRegion("us-west-2"),
	}
	cfg, err := config.LoadDefaultConfig(context.TODO(), ops...)
	if err != nil {
		return err
	}
	cwc := cloudwatchlogs.NewFromConfig(cfg)

	// pt, err := time.LoadLocation("America/Los_Angeles")
	// if err != nil {
	// 	return err
	// }
	now := time.Now()
	start := now.Add(-20 * time.Minute)
	end := now.Add(20 * time.Minute)

	res, err := cwc.GetLogEvents(context.Background(), &cloudwatchlogs.GetLogEventsInput{
		LogStreamName: aws.String("aws/bedrock/modelinvocations"),
		Limit:         aws.Int32(5), // only return 5 events
		LogGroupName:  aws.String("bedrock"),
		StartTime:     aws.Int64(start.UnixMilli()),
		EndTime:       aws.Int64(end.UnixMilli()),
	})
	if err != nil {
		return err
	}

	for _, event := range res.Events {
		log := &ModelInvocationLog{}
		if err := json.Unmarshal([]byte(*event.Message), log); err != nil {
			return err
		}
		// filter StopReason guardrail_intervened
		if log.Output.OutputBodyJson.StopReason != "guardrail_intervened" {
			continue
		}
		fmt.Printf("=======\nevent: %v\n\n", log)
	}
	return nil
}

// ModelInvocationLog is log event with fields related to the app.
type ModelInvocationLog struct {
	Identity struct {
		Arn string
	}

	Region  string
	ModelId string
	Input   struct {
		InputBodyJson struct {
			Messages []struct {
				Role    string
				Content []struct {
					Text string
				}
			}
		}
	}

	Output struct {
		OutputBodyJson struct {
			Output struct {
				Message struct {
					Role    string
					Content []struct {
						Text string
					}
				}
			}
			StopReason string
		}
	}
}
