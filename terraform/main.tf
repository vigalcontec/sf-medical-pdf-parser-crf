# =============================================================================
# Step Functions State Machine
# =============================================================================

# -----------------------------------------------------------------------------
# Step Functions State Machine
# -----------------------------------------------------------------------------
resource "aws_sfn_state_machine" "main" {
  name     = local.full_name
  role_arn = aws_iam_role.step_function.arn

  # ───────────────────────────────────────────────────────────────────────────
  # State Machine Definition
  # This is a simple success state - customize for your workflow
  # ───────────────────────────────────────────────────────────────────────────
  definition = jsonencode({
    Comment = "Medical PDF Parser - Triggered by S3 uploads"
    StartAt = "ProcessInput"
    States = {
      ProcessInput = {
        Type    = "Pass"
        Comment = "Process the incoming S3 event"
        Next    = "Success"
      }
      Success = {
        Type = "Succeed"
      }
    }
  })

  # ───────────────────────────────────────────────────────────────────────────
  # Example: Lambda invocation (uncomment when Lambda is ready)
  # ───────────────────────────────────────────────────────────────────────────
  # definition = jsonencode({
  #   Comment = "Medical PDF Parser - Triggered by S3 uploads"
  #   StartAt = "ParsePDF"
  #   States = {
  #     ParsePDF = {
  #       Type     = "Task"
  #       Resource = local.lambda_arns["medical-pdf-parser"]
  #       End      = true
  #       Retry = [
  #         {
  #           ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
  #           IntervalSeconds = 2
  #           MaxAttempts     = 3
  #           BackoffRate     = 2
  #         }
  #       ]
  #       Catch = [
  #         {
  #           ErrorEquals = ["States.ALL"]
  #           Next        = "FailState"
  #         }
  #       ]
  #     }
  #     FailState = {
  #       Type  = "Fail"
  #       Error = "PDFParserError"
  #       Cause = "PDF parsing failed after retries"
  #     }
  #   }
  # })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.main.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = local.full_name
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "main" {
  name              = "/aws/states/${local.project_name}/stepfunction/${local.function_name}"
  retention_in_days = local.log_retention_days

  tags = local.common_tags
}
