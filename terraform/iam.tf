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
# Step Function Lambda Policy - Invoke Textract Lambda
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "step_function_lambda" {
  count = length(local.lambda_functions) > 0 ? 1 : 0
  name  = "${local.full_name}-sfn-lambda"
  role  = aws_iam_role.step_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeLambda"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          for arn in values(local.lambda_arns) : "${arn}*"
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Step Function S3 Policy - Read events.json for Distributed Map
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "step_function_s3" {
  name = "${local.full_name}-sfn-s3"
  role = aws_iam_role.step_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadEvents"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          local.datalake.raw.bucket_arn,
          "${local.datalake.raw.bucket_arn}/crf/clinical_pdfs/*"
        ]
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          local.datalake.raw.kms_key_arn
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Step Function DynamoDB Policy - Update job status
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "step_function_dynamodb" {
  name = "${local.full_name}-sfn-dynamodb"
  role = aws_iam_role.step_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBUpdateJob"
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = [
          local.dynamodb.clinical_pdf_jobs.table_arn
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Step Function Distributed Map Policy - Start child executions
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "step_function_distributed_map" {
  name = "${local.full_name}-sfn-distributed-map"
  role = aws_iam_role.step_function.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StartExecution"
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          "arn:aws:states:${local.aws_region}:${local.account_id}:stateMachine:${local.full_name}"
        ]
      },
      {
        Sid    = "ManageExecutions"
        Effect = "Allow"
        Action = [
          "states:DescribeExecution",
          "states:StopExecution"
        ]
        Resource = [
          "arn:aws:states:${local.aws_region}:${local.account_id}:execution:${local.full_name}/*"
        ]
      },
      {
        Sid    = "RedriveExecutions"
        Effect = "Allow"
        Action = [
          "states:RedriveExecution"
        ]
        Resource = [
          "arn:aws:states:${local.aws_region}:${local.account_id}:execution:${local.full_name}/*"
        ]
      }
    ]
  })
}

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
