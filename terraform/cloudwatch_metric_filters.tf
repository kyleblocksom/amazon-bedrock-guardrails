resource "aws_cloudwatch_log_metric_filter" "bedrock_log_metrics" {
  for_each = var.bedrock_log_metric_filters

  name           = each.key
  pattern        = each.value
  log_group_name = aws_cloudwatch_log_group.bedrock.name

  metric_transformation {
    name      = each.key
    namespace = var.custom_bedrock_metrics_namespace
    value     = "1"
    unit      = "Count"
  }
}
