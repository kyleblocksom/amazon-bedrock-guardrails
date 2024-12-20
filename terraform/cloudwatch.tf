locals {
  cw_bedrock_metrics_namespace = "AWS/Bedrock/Guardrails"

  cw_metrics_names = [
    "InvocationClientErrors",
    "Invocations",
    # "InvocationLatency",
    "TextUnitCount",
    "InvocationsIntervened",
  ]

  dashboard_config = {
    widget_height     = 6
    widget_width      = 24
    default_period    = 60
    metrics_namespace = local.cw_bedrock_metrics_namespace
  }

  # Metric definitions for each guardrail
  metric_definitions = {
    for guardrail in local.guardrails : guardrail.guardrail_arn => [
      for metric_name in local.cw_metrics_names : [
        local.dashboard_config.metrics_namespace,
        metric_name,
        "GuardrailArn",
        guardrail.guardrail_arn,
        "GuardrailVersion",
        "1",
        {
          stat = "Sum"
        }
      ]
    ]
  }

  # Widget configuration for each guardrail
  guardrail_widgets = [
    for index, guardrail in local.guardrails : {
      type   = "metric"
      x      = 0
      y      = index * local.dashboard_config.widget_height
      width  = local.dashboard_config.widget_width
      height = local.dashboard_config.widget_height
      properties = {
        metrics = local.metric_definitions[guardrail.guardrail_arn]
        view    = "timeSeries"
        region  = var.aws_region
        period  = local.dashboard_config.default_period
        title   = "${guardrail.name} Metrics"
      }
    }
  ]
}

resource "aws_cloudwatch_dashboard" "bedrock_guardrails_true_native_metrics" {
  dashboard_name = "Bedrock_Guardrails_Dashboard_TF_Native"

  dashboard_body = jsonencode({
    widgets = local.guardrail_widgets
  })
}

# CloudWatch Alarm
resource "aws_cloudwatch_metric_alarm" "guardrail_intervened_alarm" {
  alarm_name          = "GuardrailIntervenedAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "InvocationsIntervened"
  namespace           = local.cw_bedrock_metrics_namespace
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This alarm triggers when a guardrail intervention occurs"
  alarm_actions       = [aws_sns_topic.guardrail_alarm_topic.arn]
}

# SNS Topic
resource "aws_sns_topic" "guardrail_alarm_topic" {
  name = "GuardrailAlarmTopic"
}
