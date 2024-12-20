package main

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"log"
	"text/template"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatchlogs"
)

const (
	logStream = "aws/bedrock/modelinvocations"
	logGroup  = "bedrock"

	modelID = "us.amazon.nova-pro-v1:0"

	systemPrompt = `Your role is to summarize CloudWatch Alarm setup for Bedrock GuardRail GuardrailIntervened metrics. The information provided to you will be in the format:
<alarm>
$ALARM_DETAILS
</alarm>
<events>
<event>
$BEDROCK_INVOCATION_DETAILS
</event>
...
</events>

Important Notes:
1. You should only respond with the summarization and nothing else.
2. If <events> is provided, you should include a summarize of the 'Input' as part of alarm summarization that includes the nature and insights of the 'Input'.

Example output:
- **Alarm Name:** GuardrailIntervenedAlarm
- **Description:** Triggers on guardrail intervention.
- **AWS Account ID:** 1111111111
- **Region:** US West (Oregon)
- **New State:** ALARM
- **Reason:** Threshold Crossed: 1 datapoint [30.0 (03/12/24 05:28:00)] > 0.0.
- **Events Summary:**
	- Blocked a comparison question about insurance policies.
	- Blocked an input containing a personal insult.
	- Blocked an input with derogatory language.
`
)

//go:embed prompt_template.tmpl
var templateString string

var promptTemplate *template.Template

func init() {
	promptTemplate = template.Must(template.New("prompt").Parse(templateString))
}

func main() {
	// Make the handler available for Remote Procedure Call by AWS Lambda
	lambda.Start(handle)
}

// handle processes CloudWatch alarm notifications received through SNS events.
// It retrieves associated log events around the alarm time and generates an AI-powered
// summary of the incident using Amazon Bedrock.
//
// Parameters:
//   - ctx context.Context: The context for the function execution, which may include deadlines
//   - req events.SNSEvent: The SNS event containing the CloudWatch alarm payload
//
// Returns:
//   - error: Returns nil for both successful execution and non-retryable errors
//
// The function performs the following operations:
//  1. Checks and logs context deadline if present
//  2. Unmarshals the SNS message into a CloudWatch alarm structure
//  3. Parses the alarm's state change timestamp
//  4. Retrieves relevant CloudWatch log events around the alarm time
//  5. Initializes a Bedrock client for AI processing
//  6. Generates a summary of the incident using Bedrock
//
// Error Handling:
//   - All errors are logged but treated as non-retryable (returns nil)
//   - JSON unmarshal errors for the SNS payload
//   - Time parsing errors for the alarm state change time
//   - Log retrieval errors
//   - Bedrock client initialization errors
//   - Summarization errors
func handle(ctx context.Context, req events.SNSEvent) error {
	if d, ok := ctx.Deadline(); ok {
		log.Printf("handle context with deadline: %v", d)
	}

	var alarm events.CloudWatchAlarmSNSPayload
	if err := json.Unmarshal([]byte(req.Records[0].SNS.Message), &alarm); err != nil {
		log.Printf("ERROR: %v\n", err)
		return nil // Non-retryable error
	}
	log.Printf("Alarm: '%s'", req.Records[0].SNS.Message) // print out raw message so we can use it for testing.

	alertTime, err := time.Parse("2006-01-02T15:04:05.000-0700", alarm.StateChangeTime)
	if err != nil {
		log.Printf("unable to parse StateChangeTime: '%s'\n", alarm.StateChangeTime)
	}

	logEvents, err := getLogEventsForAlarm(ctx, alertTime)
	if err != nil {
		log.Printf("ERROR: unable to retrieve log events for alertTime: '%s'\n", alarm.StateChangeTime)
		return nil
	}
	log.Printf("log events: %d\n", len(logEvents))
	for i, event := range logEvents {
		log.Printf("log event (%d): %v\n", i, event)
	}
	bc, err := getBedrockClient(ctx)
	if err != nil {
		log.Printf("ERROR: failed to initialize bedrockruntime.Client: '%s'\n", err)
		return nil
	}

	summarization, err := Summarize(ctx, bc, alarm, logEvents)
	if err != nil {
		log.Printf("ERROR: summarize: %v\n", err)
		return nil
	}
	log.Printf("Summarization: %s\n", summarization)
	return nil
}

// getLogEventsForAlarm retrieves and filters CloudWatch log events related to Bedrock model invocations
// that triggered guardrail interventions within a time window around the specified alarm time.
//
// The function will:
//  1. Set up a 5-minute timeout context
//  2. Initialize AWS CloudWatch Logs client
//  3. Query logs within the time window
//  4. Filter for events with StopReason "guardrail_intervened"
//  5. Parse and return matching events
func getLogEventsForAlarm(pctx context.Context, alarmTime time.Time) ([]*ModelInvocationLog, error) {
	ctx, cancel := context.WithTimeout(pctx, 5*time.Minute) // 5 mins timeout.
	defer cancel()
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, err
	}
	cwc := cloudwatchlogs.NewFromConfig(cfg)

	if alarmTime.IsZero() {
		alarmTime = time.Now()
	}
	start := alarmTime.Add(-5 * time.Minute)
	end := alarmTime.Add(5 * time.Minute)
	logRes, err := cwc.GetLogEvents(ctx, &cloudwatchlogs.GetLogEventsInput{
		LogStreamName: aws.String("aws/bedrock/modelinvocations"),
		Limit:         aws.Int32(5), // only return 5 events
		LogGroupName:  aws.String("bedrock"),
		StartTime:     aws.Int64(start.UnixMilli()),
		EndTime:       aws.Int64(end.UnixMilli()),
	})
	if err != nil {
		return nil, err
	}
	var res []*ModelInvocationLog
	for _, event := range logRes.Events {
		l := &ModelInvocationLog{}
		if err := json.Unmarshal([]byte(*event.Message), l); err != nil {
			return nil, err
		}
		// filter StopReason guardrail_intervened
		if l.Output.OutputBodyJson.StopReason != "guardrail_intervened" {
			continue
		}

		res = append(res, l)
		log.Printf("event.Message: '%s'", *event.Message)
	}
	return res, nil
}

// Summarize generates a natural language summary of CloudWatch alarm events using Amazon Bedrock's Nova model.
// It processes the alarm data and related model invocation logs to create a contextual summary of the events.
//
// The function performs the following steps:
//  1. Generates a summarization prompt using the alarm and events data
//  2. Constructs a Nova model request with system and user messages
//  3. Invokes the Nova model through Amazon Bedrock
//  4. Processes and returns the model's response
func Summarize(ctx context.Context, bc *bedrockruntime.Client, alarm events.CloudWatchAlarmSNSPayload, events []*ModelInvocationLog) (string, error) {
	prompt, err := getSummarizationPrompt(alarm, events)
	if err != nil {
		return "", err
	}

	req := &NovaRequest{
		System: []*ClaudeMessageContent{
			{Text: systemPrompt},
		},
		Messages: []*ClaudeMessage{
			{
				Role: "user",
				Content: []*ClaudeMessageContent{
					{
						Text: prompt,
					},
				},
			},
		},
	}

	b, err := json.Marshal(req)
	if err != nil {
		return "", err
	}

	input := &bedrockruntime.InvokeModelInput{
		Accept:      aws.String("application/json"),
		ContentType: aws.String("application/json"),
		ModelId:     aws.String(modelID),
		Body:        b,
	}

	res, err := bc.InvokeModel(ctx, input)
	if err != nil {
		return "", err
	}

	claudeRes := &NovaResponse{}
	if err := json.Unmarshal(res.Body, claudeRes); err != nil {
		return "", err
	}
	return claudeRes.Output.Message.Content[0].Text, nil
}

func getBedrockClient(ctx context.Context) (*bedrockruntime.Client, error) {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, err
	}
	bc := bedrockruntime.NewFromConfig(cfg)
	return bc, nil
}

func getSummarizationPrompt(alarm events.CloudWatchAlarmSNSPayload, events []*ModelInvocationLog) (string, error) {
	var b []byte
	buf := bytes.NewBuffer(b)
	params := PromptTemplateParams{
		Alarm:  alarm,
		Events: events,
	}
	if err := promptTemplate.Execute(buf, params); err != nil {
		return "", err
	}
	return buf.String(), nil
}

// ClaudeMessageRequest represents the request structure for invoking the Claude model through Amazon Bedrock.
// It contains the system prompt, version information, token limits and message content.
type ClaudeMessageRequest struct {
	// System contains the system prompt that provides context and instructions to the model
	System string `json:"system,omitempty"`

	// AnthropicVersion specifies the model version to use (e.g. "bedrock-2023-05-31")
	AnthropicVersion string `json:"anthropic_version,omitempty"`

	// MaxTokens limits the length of the response. The model will aim to generate a response
	// that is no longer than this number of tokens
	MaxTokens int32 `json:"max_tokens,omitempty"`

	// Messages contains the conversation history and current prompt in a structured format
	Messages []*ClaudeMessage `json:"messages"`
}

type ClaudeMessageResponse struct {
	Role    string                  `json:"role,omitempty"`
	Content []*ClaudeMessageContent `json:"content,omitempty"`
}

type NovaRequest struct {
	System   []*ClaudeMessageContent `json:"system,omitempty"`
	Messages []*ClaudeMessage        `json:"messages"`
}

type NovaResponse struct {
	Output struct {
		Message *ClaudeMessage `json:"message"`
	} `json:"output"`
}

type ClaudeMessage struct {
	Role    string                  `json:"role,omitempty"`
	Content []*ClaudeMessageContent `json:"content,omitempty"`
}

type ClaudeMessageContent struct {
	Type string `json:"type,omitempty"`
	Text string `json:"text,omitempty"`
}

type PromptTemplateParams struct {
	Alarm  events.CloudWatchAlarmSNSPayload
	Events []*ModelInvocationLog
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
