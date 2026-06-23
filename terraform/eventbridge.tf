# =============================================================================
# EventBridge - S3 Event Trigger
# =============================================================================
# Triggers the Step Function when objects are created in S3.
# Enable/disable in config.tf: local.s3_trigger.enabled

# -----------------------------------------------------------------------------
# EventBridge Rule - S3 Object Created
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "s3_trigger" {
  count       = local.s3_trigger.enabled ? 1 : 0
  name        = "${local.full_name}-s3-trigger"
  description = "Trigger Step Function when the events are created in S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [local.datalake.raw.bucket_name]
      }
      object = {
        key = [{
          wildcard = "${local.s3_trigger.prefix}*${local.s3_trigger.suffix}"
        }]
      }
    }
  })

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# EventBridge Target - Step Function
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_event_target" "step_function" {
  count     = local.s3_trigger.enabled ? 1 : 0
  rule      = aws_cloudwatch_event_rule.s3_trigger[0].name
  target_id = "TriggerStepFunction"
  arn       = aws_sfn_state_machine.main.arn
  role_arn  = aws_iam_role.eventbridge[0].arn

  input_transformer {
    input_paths = {
      bucket    = "$.detail.bucket.name"
      key       = "$.detail.object.key"
      size      = "$.detail.object.size"
      eventTime = "$.time"
    }
    input_template = <<EOF
{
  "bucket": <bucket>,
  "key": <key>,
  "size": <size>,
  "eventTime": <eventTime>,
  "environment": "${var.environment}"
}
EOF
  }
}
