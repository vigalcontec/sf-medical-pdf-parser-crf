# =============================================================================
# Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Step Function
# -----------------------------------------------------------------------------
output "state_machine_arn" {
  description = "Step Function state machine ARN"
  value       = aws_sfn_state_machine.main.arn
}

output "state_machine_name" {
  description = "Step Function state machine name"
  value       = aws_sfn_state_machine.main.name
}

output "state_machine_role_arn" {
  description = "Step Function execution role ARN"
  value       = aws_iam_role.step_function.arn
}

# -----------------------------------------------------------------------------
# CloudWatch Logs
# -----------------------------------------------------------------------------
output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.main.name
}

output "log_group_arn" {
  description = "CloudWatch Log Group ARN"
  value       = aws_cloudwatch_log_group.main.arn
}

# -----------------------------------------------------------------------------
# EventBridge (when S3 trigger is enabled)
# -----------------------------------------------------------------------------
output "event_rule_arn" {
  description = "EventBridge rule ARN"
  value       = local.s3_trigger.enabled ? aws_cloudwatch_event_rule.s3_trigger[0].arn : null
}

# -----------------------------------------------------------------------------
# S3 Trigger Configuration
# -----------------------------------------------------------------------------
output "s3_trigger_bucket" {
  description = "S3 bucket being monitored"
  value       = local.s3_trigger.enabled ? local.datalake.raw.bucket_name : null
  sensitive   = true
}

output "s3_trigger_prefix" {
  description = "S3 prefix being monitored"
  value       = local.s3_trigger.enabled ? local.s3_trigger.prefix : null
}
