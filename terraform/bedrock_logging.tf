resource "aws_cloudwatch_log_group" "bedrock" {
  name = var.cloudwatch_log_group_name

  tags = {
    Environment = "development"
    Application = "bedrock-guardrails-cw-metrics"
  }
}

resource "aws_iam_role" "cloudwatch_bedrock_logging" {
  name = "CloudWatchBedrockLoggingRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${data.aws_caller_identity.current.account_id}"
          }
          ArnLike = {
            "AWS:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "AmazonBedrockCloudwatchLogGroupPolicy" {
  name = "AmazonBedrockCloudwatchLogGroupPolicy"
  role = aws_iam_role.cloudwatch_bedrock_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:*"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_cloudwatch_log_group.bedrock.arn}*"
        ]
      },
    ]
  })
}

# see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrock_model_invocation_logging_configuration
# and: https://docs.aws.amazon.com/bedrock/latest/userguide/model-invocation-logging.html#model-invocation-logging-console
resource "aws_bedrock_model_invocation_logging_configuration" "enable_cloudwatch" {
  logging_config {
    embedding_data_delivery_enabled = true
    image_data_delivery_enabled     = true
    text_data_delivery_enabled      = true

    cloudwatch_config {
      log_group_name = var.cloudwatch_log_group_name
      role_arn       = aws_iam_role.cloudwatch_bedrock_logging.arn
    }
  }
}


output "aws_cloudwatch_log_group_bedrock_arn" {
  value = aws_cloudwatch_log_group.bedrock.arn
}

output "aws_cloudwatch_log_group_bedrock_name" {
  value = aws_cloudwatch_log_group.bedrock.name
}
