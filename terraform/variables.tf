variable "aws_region" {
  description = "The AWS Region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "custom_bedrock_metrics_namespace" {
  description = "The custom metric filter namespace for Amazon Bedrock"
  type        = string
  default     = "Custom/Bedrock/Guardrails"
}

variable "native_bedrock_metrics_namespace" {
  description = "The native metric namespace for Amazon Bedrock"
  type        = string
  default     = "AWS/Bedrock/Guardrails"
}

variable "cloudwatch_log_group_name" {
  description = "The name of the Amazon CloudWatch log group for Amazon Bedrock invocation logging"
  type        = string
  default     = "bedrock"
}

variable "guardrails" {
  description = "List of guardrail names"
  type        = list(string)
  default = [
    "Denied-Insurance-Claims-Policy",
    "Content-Filtering",
    "Mask-PII",
    "Block-PII",
    "Denied-Topics",
    "Word-Filters"
  ]
}

variable "bedrock_log_metric_filters" {
  description = "Metric patterns for guardrails"
  type        = map(string)
  default = {
    # Guardrail intervention metrics
    "GUARDRAIL_INTERVENED"     = "{ $.output.outputBodyJson.stopReason = \"guardrail_intervened\" }"
    "GUARDRAIL_NOT_INTERVENED" = "{ $.output.outputBodyJson.stopReason = \"end_turn\" }"

    # Content policy metrics
    "CONTENT_POLICY_BLOCKED" = "{ $.output.outputBodyJson.trace.guardrail.inputAssessment.*.contentPolicy.filters[0].action = \"BLOCKED\" }"
    "SEXUAL_CONTENT_BLOCKED" = "{ $.output.outputBodyJson.trace.guardrail.inputAssessment.*.contentPolicy.filters[0].type = \"SEXUAL\" && $.output.outputBodyJson.trace.guardrail.inputAssessment.*.contentPolicy.filters[0].action = \"BLOCKED\" }"
    "PROMPT_ATTACK_BLOCKED"  = "{ $.output.outputBodyJson.trace.guardrail.inputAssessment.*.contentPolicy.filters[0].type = \"PROMPT_ATTACK\" && $.output.outputBodyJson.trace.guardrail.inputAssessment.*.contentPolicy.filters[0].action = \"BLOCKED\" }"

    # Confidence level metrics
    "HIGH_CONFIDENCE_BLOCK" = "{ $.output.outputBodyJson.trace.guardrail.inputAssessment.*.contentPolicy.filters[0].confidence = \"HIGH\" && $.output.outputBodyJson.trace.guardrail.inputAssessment.*.contentPolicy.filters[0].action = \"BLOCKED\" }"
    "LOW_CONFIDENCE_BLOCK"  = "{ $.output.outputBodyJson.trace.guardrail.inputAssessment.*.contentPolicy.filters[0].confidence = \"LOW\" && $.output.outputBodyJson.trace.guardrail.inputAssessment.*.contentPolicy.filters[0].action = \"BLOCKED\" }"

    # Latency metrics
    "HIGH_LATENCY"                      = "{ $.output.outputBodyJson.metrics.latencyMs > 1000 }"
    "HIGH_GUARDRAIL_PROCESSING_LATENCY" = "{ $.output.outputBodyJson.trace.guardrail.inputAssessment.*.invocationMetrics.guardrailProcessingLatency > 500 }"

    # Usage metrics
    "CONTENT_POLICY_USAGE"        = "{ $.output.outputBodyJson.trace.guardrail.inputAssessment.*.invocationMetrics.usage.contentPolicyUnits > 0 }"
    "TOPIC_POLICY_USAGE"          = "{ $.output.outputBodyJson.trace.guardrail.inputAssessment.*.invocationMetrics.usage.topicPolicyUnits > 0 }"
    "WORD_POLICY_USAGE"           = "{ $.output.outputBodyJson.trace.guardrail.inputAssessment.*.invocationMetrics.usage.wordPolicyUnits > 0 }"
    "SENSITIVE_INFO_POLICY_USAGE" = "{ $.output.outputBodyJson.trace.guardrail.inputAssessment.*.invocationMetrics.usage.sensitiveInformationPolicyUnits > 0 }"

    # Guardrail coverage metrics
    "HIGH_GUARDRAIL_COVERAGE" = "{ $.output.outputBodyJson.trace.guardrail.inputAssessment.*.invocationMetrics.guardrailCoverage.textCharacters.guarded > 900 && $.output.outputBodyJson.trace.guardrail.inputAssessment.*.invocationMetrics.guardrailCoverage.textCharacters.total = 1000 }"

    # Token usage metrics
    "HIGH_TOKEN_USAGE" = "{ $.output.outputBodyJson.usage.totalTokens > 1000 }"
  }
}

variable "lookback_period" {
  description = "The metric lookback period in minutes"
  type        = number
  default     = 5
}

variable "plot_template" {
  description = "The Plotly template to use for plotting"
  type        = string
  default     = "plotly"
}

variable "lambda_timeout_seconds" {
  description = "AWS Lambda function timeout"
  type        = number
  default     = 30
}

variable "batch_delay" {
  description = "The delay in seconds between Converse API calls to avoid throttling"
  type        = number
  default     = 1
}
output "aws_region" {
  value = var.aws_region
}
