# =============================================================================
# IAM Roles and Policies
# =============================================================================

# -----------------------------------------------------------------------------
# Step Function Execution Role
# -----------------------------------------------------------------------------
resource "aws_iam_role" "step_function" {
  name = "${local.full_name}-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.full_name}-sfn"
  })
}

# -----------------------------------------------------------------------------
# Step Function Base Policy - CloudWatch Logs & X-Ray
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "step_function_base" {
  name = "${local.full_name}-sfn-base"
  role = aws_iam_role.step_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "XRayTracing"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Step Function Lambda Policy (uncomment if invoking Lambda functions)
# -----------------------------------------------------------------------------
# resource "aws_iam_role_policy" "step_function_lambda" {
#   count = length(local.lambda_functions) > 0 ? 1 : 0
#   name  = "${local.full_name}-sfn-lambda"
#   role  = aws_iam_role.step_function.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "InvokeLambda"
#         Effect = "Allow"
#         Action = [
#           "lambda:InvokeFunction"
#         ]
#         Resource = [
#           for arn in values(local.lambda_arns) : "${arn}*"
#         ]
#       }
#     ]
#   })
# }

# -----------------------------------------------------------------------------
# EventBridge Role (for S3 trigger)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "eventbridge" {
  count = local.s3_trigger.enabled ? 1 : 0
  name  = "${local.full_name}-eventbridge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.full_name}-eventbridge"
  })
}

resource "aws_iam_role_policy" "eventbridge" {
  count = local.s3_trigger.enabled ? 1 : 0
  name  = "${local.full_name}-eventbridge-policy"
  role  = aws_iam_role.eventbridge[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StartStepFunction"
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.main.arn
      }
    ]
  })
}
