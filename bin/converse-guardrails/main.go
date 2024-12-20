package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime/types"
)

const (
	testDataPath = "test_data/bedrock_inputs.json"
	tfOutputPath = "notebook/tf_output.json"
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
	// setup bedrockruntime client.
	var ops = []func(*config.LoadOptions) error{
		config.WithSharedConfigProfile("bedrock-guardrails-cw-metrics"),
		config.WithDefaultRegion("us-west-2"),
	}
	cfg, err := config.LoadDefaultConfig(context.TODO(), ops...)
	if err != nil {
		return err
	}

	bc := bedrockruntime.NewFromConfig(cfg)

	// read test data
	d, err := readTestData(testDataPath)
	if err != nil {
		return err
	}
	fmt.Println(d)

	// read tf_output.json
	o, err := readTfOutput(tfOutputPath)
	if err != nil {
		return err
	}
	fmt.Println(o)

	// call .Converse for every test input.
	fmt.Println("---- Test Bedrock Converse With Guardrail ---")
	for _, testCase := range d.Data {
		// find guardrail ID for testCase's Guardrail name.
		id, ok := o.GuardrailIds.Value[testCase.GuardrailName]
		if !ok {
			fmt.Printf("\n Unable to find GuardRail ID for Guardrail Name (%s) in Test data", testCase.GuardrailName)
			continue
		}
		fmt.Printf("\n\n== Guardrail Name: '%s', ID: '%s'==\n", testCase.GuardrailName, id)

		for _, input := range testCase.Inputs {
			fmt.Printf("\nInput: '%s'\n", input)
			cInput := &bedrockruntime.ConverseInput{
				ModelId: aws.String("anthropic.claude-3-haiku-20240307-v1:0"),
				GuardrailConfig: &types.GuardrailConfiguration{
					GuardrailIdentifier: aws.String(id),
					GuardrailVersion:    aws.String("1"), // this is hardcoded to 1 in terraform
				},
				Messages: []types.Message{
					{
						Role: types.ConversationRoleUser,
						Content: []types.ContentBlock{
							&types.ContentBlockMemberText{
								Value: input,
							},
						},
					},
				},
			}

			res, err := bc.Converse(context.Background(), cInput)
			if err != nil {
				return err
			}
			if res.StopReason != types.StopReasonGuardrailIntervened {
				fmt.Printf("Error: Expect StopReason to be 'GuardrailIntervene' but got: '%s'\n", res.StopReason)
				continue
			}
			msg := res.Output.(*types.ConverseOutputMemberMessage)
			fmt.Printf("Output: '%s'\n", msg.Value.Content[0].(*types.ContentBlockMemberText).Value)
		}
	}
	return nil
}

// readTestData reads the test data.
func readTestData(path string) (*TestData, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	res := &TestData{}
	if err := json.Unmarshal(b, res); err != nil {
		return nil, err
	}
	return res, nil
}

type TestCase struct {
	GuardrailName string   `json:"guardrail_name"`
	Inputs        []string `json:"inputs"`
}

type TestData struct {
	Data []TestCase
}

func readTfOutput(path string) (*TfOutput, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	res := &TfOutput{}
	if err := json.Unmarshal(b, res); err != nil {
		return nil, err
	}
	return res, nil
}

type TfOutput struct {
	GuardrailIds struct {
		Value map[string]string
	} `json:"guardrail_ids"`
}
