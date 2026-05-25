# =============================================================================
# Step Functions State Machine - Clinical PDF Table Extraction Pipeline
# =============================================================================
# Triggered by _events.json files created by the Locator Lambda.
# Uses Distributed Map to process each table event in parallel.

# -----------------------------------------------------------------------------
# Step Functions State Machine
# -----------------------------------------------------------------------------
resource "aws_sfn_state_machine" "main" {
  name     = local.full_name
  role_arn = aws_iam_role.step_function.arn

  # ───────────────────────────────────────────────────────────────────────────
  # State Machine Definition - Distributed Map for Table Extraction
  # ───────────────────────────────────────────────────────────────────────────
  definition = jsonencode({
    Comment = "Clinical PDF Table Extraction Pipeline - Distributed Map"
    StartAt = "ExtractJobIdFromKey"
    States = {
      # ─────────────────────────────────────────────────────────────────────────
      # Extract job_id from the events file key
      # Input: { bucket, key } from EventBridge
      # ─────────────────────────────────────────────────────────────────────────
      ExtractJobIdFromKey = {
        Type = "Pass"
        Parameters = {
          "s3_bucket.$"    = "$.bucket"
          "events_s3_key.$" = "$.key"
          # job_id will be passed from DynamoDB lookup or derived
        }
        Next = "ProcessTableEvents"
      }

      # ─────────────────────────────────────────────────────────────────────────
      # Distributed Map - Process each table event in parallel
      # Reads the JSON array from S3 and invokes Lambda for each item
      # ─────────────────────────────────────────────────────────────────────────
      ProcessTableEvents = {
        Type = "Map"
        ItemReader = {
          Resource = "arn:aws:states:::s3:getObject"
          ReaderConfig = {
            InputType = "JSON"
          }
          Parameters = {
            "Bucket.$" = "$.s3_bucket"
            "Key.$"    = "$.events_s3_key"
          }
        }
        ItemSelector = {
          "s3_bucket.$"          = "$$.Map.Item.Value.s3_bucket"
          "s3_key.$"             = "$$.Map.Item.Value.s3_key"
          "product_name.$"       = "$$.Map.Item.Value.product_name"
          "table_name.$"         = "$$.Map.Item.Value.table_name"
          "table_number.$"       = "$$.Map.Item.Value.table_number"
          "page.$"               = "$$.Map.Item.Value.page"
          "table_index_on_page.$" = "$$.Map.Item.Value.table_index_on_page"
          "events_s3_key.$"      = "$.events_s3_key"
        }
        MaxConcurrency = local.distributed_map.max_concurrency
        ToleratedFailurePercentage = local.distributed_map.tolerated_failure_percentage
        ItemProcessor = {
          ProcessorConfig = {
            Mode          = "DISTRIBUTED"
            ExecutionType = "STANDARD"
          }
          StartAt = "ExtractTableWithTextract"
          States = {
            # ─────────────────────────────────────────────────────────────────
            # Invoke Textract Lambda for each table/page
            # ─────────────────────────────────────────────────────────────────
            ExtractTableWithTextract = {
              Type     = "Task"
              Resource = "arn:aws:states:::lambda:invoke"
              Parameters = {
                FunctionName = local.lambda_arns["clinical-pdf-textract-crf"]
                "Payload.$"  = "$"
              }
              Retry = [
                {
                  ErrorEquals = [
                    "Lambda.ServiceException",
                    "Lambda.AWSLambdaException",
                    "Lambda.TooManyRequestsException",
                    "Lambda.SdkClientException"
                  ]
                  IntervalSeconds = 2
                  MaxAttempts     = 3
                  BackoffRate     = 2
                }
              ]
              ResultPath = "$.lambda_result"
              End        = true
            }
          }
        }
        ResultPath = "$.map_results"
        Next       = "UpdateJobStatusSuccess"
      }

      # ─────────────────────────────────────────────────────────────────────────
      # Update DynamoDB job status to SUCCESS
      # ─────────────────────────────────────────────────────────────────────────
      UpdateJobStatusSuccess = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:updateItem"
        Parameters = {
          TableName = local.dynamodb.clinical_pdf_jobs.table_name
          Key = {
            PK = { "S.$" = "States.Format('JOB#{}', $.job_id)" }
            SK = { S = "METADATA" }
          }
          UpdateExpression = "SET #status = :status, updated_at = :now, GSI1PK = :gsi1pk, GSI1SK = :now"
          ExpressionAttributeNames = {
            "#status" = "status"
          }
          ExpressionAttributeValues = {
            ":status"  = { S = "SUCCESS" }
            ":now"     = { "S.$" = "$$.State.EnteredTime" }
            ":gsi1pk"  = { S = "STATUS#SUCCESS" }
          }
        }
        End = true
      }
    }
  })

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
# Standard path: /aws/{project_name}/{tool}/{stack_name}
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "main" {
  name              = "/aws/${local.project_name}/stepfunction/${local.function_name}"
  retention_in_days = local.log_retention_days

  tags = local.common_tags
}
