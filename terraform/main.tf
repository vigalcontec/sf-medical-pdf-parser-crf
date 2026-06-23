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
    StartAt = "PrepareInput"
    States = {
      # ─────────────────────────────────────────────────────────────────────────
      # Prepare input for Distributed Map
      # Input: { bucket, key } from EventBridge
      # ─────────────────────────────────────────────────────────────────────────
      PrepareInput = {
        Type = "Pass"
        Parameters = {
          "s3_bucket.$"     = "$.bucket"
          "events_s3_key.$" = "$.key"
        }
        Next = "ProcessTableEvents"
      }

      # ─────────────────────────────────────────────────────────────────────────
      # Distributed Map - Process each table event in parallel
      # Reads the JSON array from S3 and invokes Lambda for each item
      # Each event contains job_id for tracking
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
          "job_id.$"              = "$$.Map.Item.Value.job_id"
          "s3_bucket.$"           = "$$.Map.Item.Value.s3_bucket"
          "s3_key.$"              = "$$.Map.Item.Value.s3_key"
          "product_name.$"        = "$$.Map.Item.Value.product_name"
          "table_name.$"          = "$$.Map.Item.Value.table_name"
          "table_number.$"        = "$$.Map.Item.Value.table_number"
          "page.$"                = "$$.Map.Item.Value.page"
          "table_index_on_page.$" = "$$.Map.Item.Value.table_index_on_page"
          "events_s3_key.$"       = "$.events_s3_key"
        }
        MaxConcurrency             = local.distributed_map.max_concurrency
        ToleratedFailurePercentage = local.distributed_map.tolerated_failure_percentage
        ItemProcessor = {
          ProcessorConfig = {
            Mode          = "DISTRIBUTED"
            ExecutionType = "STANDARD"
          }
          StartAt = "ExtractTableWithTextract"
          States = {
            # ─────────────────────────────────────────────────────────────────
            # Step 1: Invoke Textract Lambda for each table/page
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
              ResultSelector = {
                "status.$"               = "$.Payload.status"
                "reason.$"               = "$.Payload.reason"
                "job_id.$"               = "$.Payload.job_id"
                "s3_bucket.$"            = "$.Payload.s3_bucket"
                "s3_key.$"               = "$.Payload.s3_key"
                "product_name.$"         = "$.Payload.product_name"
                "table_name.$"           = "$.Payload.table_name"
                "table_number.$"         = "$.Payload.table_number"
                "page.$"                 = "$.Payload.page"
                "pages_processed.$"      = "$.Payload.pages_processed"
                "table_index_on_page.$"  = "$.Payload.table_index_on_page"
                "tables_found_on_page.$" = "$.Payload.tables_found_on_page"
                "table.$"                = "$.Payload.table"
                "formulations.$"         = "$.Payload.formulations"
                "formulation_key.$"      = "$.Payload.formulation_key"
              }
              Next = "CheckTextractStatus"
              Catch = [
                {
                  ErrorEquals = ["States.ALL"]
                  ResultPath  = "$.error_info"
                  Next        = "HandleTextractError"
                }
              ]
            }

            # ─────────────────────────────────────────────────────────────────
            # Step 1b: Check if Textract found table data
            # Skip normalization if no table was found or index out of range
            # ─────────────────────────────────────────────────────────────────
            CheckTextractStatus = {
              Type = "Choice"
              Choices = [
                {
                  Variable      = "$.status"
                  StringEquals  = "NO_TABLE_FOUND"
                  Next          = "SkipNormalization"
                },
                {
                  Variable      = "$.status"
                  StringEquals  = "TABLE_INDEX_OUT_OF_RANGE"
                  Next          = "SkipNormalization"
                }
              ]
              Default = "NormalizeTableWithClaude"
            }

            # ─────────────────────────────────────────────────────────────────
            # Handle skipped tables (no data found)
            # ─────────────────────────────────────────────────────────────────
            SkipNormalization = {
              Type = "Pass"
              Parameters = {
                "status"         = "SKIPPED"
                "reason.$"       = "$.reason"
                "job_id.$"       = "$.job_id"
                "product_name.$" = "$.product_name"
                "table_name.$"   = "$.table_name"
                "table_number.$" = "$.table_number"
                "page.$"         = "$.page"
              }
              End = true
            }

            # ─────────────────────────────────────────────────────────────────
            # Handle Textract errors
            # ─────────────────────────────────────────────────────────────────
            HandleTextractError = {
              Type = "Pass"
              Parameters = {
                "status"  = "FAILED"
                "stage"   = "textract"
                "error.$" = "$.error_info"
              }
              End = true
            }

            # ─────────────────────────────────────────────────────────────────
            # Step 2: Normalize extracted table data with Claude AI
            # ─────────────────────────────────────────────────────────────────
            NormalizeTableWithClaude = {
              Type     = "Task"
              Resource = "arn:aws:states:::lambda:invoke"
              Parameters = {
                FunctionName = local.lambda_arns["clinical-pdf-normalization-crf"]
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
                  IntervalSeconds = 5
                  MaxAttempts     = 2
                  BackoffRate     = 2
                }
              ]
              ResultSelector = {
                "job_id.$"               = "$.Payload.job_id"
                "status.$"               = "$.Payload.status"
                "product_name.$"         = "$.Payload.product_name"
                "table_name.$"           = "$.Payload.table_name"
                "table_number.$"         = "$.Payload.table_number"
                "page.$"                 = "$.Payload.page"
                "table_type_detected.$"  = "$.Payload.table_type_detected"
                "normalization_status.$" = "$.Payload.normalization_status"
                "output_uri.$"           = "$.Payload.output_uri"
              }
              Catch = [
                {
                  ErrorEquals = ["States.ALL"]
                  ResultPath  = "$.normalization_error"
                  Next        = "HandleNormalizationError"
                }
              ]
              Next = "ItemComplete"
            }
            HandleNormalizationError = {
              Type = "Pass"
              Parameters = {
                "status"  = "FAILED"
                "error.$" = "$.normalization_error"
              }
              End = true
            }
            ItemComplete = {
              Type = "Pass"
              End  = true
            }
          }
        }
        ResultPath = "$.map_results"
        Next       = "UpdateJobStatusSuccess"
      }

      # ─────────────────────────────────────────────────────────────────────────
      # Update DynamoDB job status to SUCCESS
      # Gets job_id from the first item in map_results array
      # ─────────────────────────────────────────────────────────────────────────
      UpdateJobStatusSuccess = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:updateItem"
        Parameters = {
          TableName = local.dynamodb.clinical_pdf_jobs.table_name
          Key = {
            # Get job_id from the first item in map_results array
            PK = { "S.$" = "States.Format('JOB#{}', $.map_results[0].job_id)" }
            SK = { S = "METADATA" }
          }
          UpdateExpression = "SET #status = :status, updated_at = :now, GSI1PK = :gsi1pk, GSI1SK = :now"
          ExpressionAttributeNames = {
            "#status" = "status"
          }
          ExpressionAttributeValues = {
            ":status" = { S = "SUCCESS" }
            ":now"    = { "S.$" = "$$.State.EnteredTime" }
            ":gsi1pk" = { S = "STATUS#SUCCESS" }
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
