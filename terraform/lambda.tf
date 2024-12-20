locals {
  lambda_archive_path    = "../lambda/bedrock_log_automation.zip"
  lambda_go_archive_path = "../lambda/bedrock_log_automation_go.zip"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "guardrail_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "guardrail_lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:GetLogRecord" // TODO: remove not used
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      // allows lambda to use bedrock
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          // allows cross-region inference via bedrock
          // see: https://aws.amazon.com/blogs/machine-learning/getting-started-with-cross-region-inference-in-amazon-bedrock/
          "arn:aws:bedrock:us-east-1:${data.aws_caller_identity.current.account_id}:inference-profile/*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/*",
        ]
      }
    ]
  })
}


data "archive_file" "lambda" {
  type        = "zip"
  source_file = "../lambda/bedrock_log_automation.py"
  output_path = local.lambda_archive_path
}

# Lambda Function
resource "aws_lambda_function" "guardrail_alarm_handler" {
  # count = 0 // disable for now.

  filename      = local.lambda_archive_path
  function_name = "GuardrailAlarmHandler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  timeout = var.lambda_timeout_seconds

  source_code_hash = data.archive_file.lambda.output_base64sha256
}

# Lambda Permission for SNS
resource "aws_lambda_permission" "sns_lambda" {
  # count = 1

  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.guardrail_alarm_handler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.guardrail_alarm_topic.arn
}


# SNS Topic Subscription
resource "aws_sns_topic_subscription" "guardrail_alarm_subscription" {
  topic_arn = aws_sns_topic.guardrail_alarm_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.guardrail_alarm_handler.arn
}

## Go Lambda

data "archive_file" "lambda_go" {
  type        = "zip"
  source_file = "../lambda/build/bootstrap"
  output_path = local.lambda_go_archive_path
}

# Lambda Function
resource "aws_lambda_function" "guardrail_alarm_handler_go" {
  # count = 0 // disable for now.

  filename      = local.lambda_go_archive_path
  function_name = "GuardrailAlarmHandler-Go"
  role          = aws_iam_role.lambda_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  timeout       = var.lambda_timeout_seconds

  source_code_hash = data.archive_file.lambda_go.output_base64sha256
}

# Lambda Permission for SNS
resource "aws_lambda_permission" "sns_lambda_go" {
  # count = 0

  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.guardrail_alarm_handler_go.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.guardrail_alarm_topic.arn
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "guardrail_alarm_subscription_go" {
  topic_arn = aws_sns_topic.guardrail_alarm_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.guardrail_alarm_handler_go.arn
}
