# =============================================================================
# Configuration - Update these values for your project
# =============================================================================

locals {
  # ─────────────────────────────────────────────────────────────────────────────
  # Project Configuration (UPDATE THESE)
  # ─────────────────────────────────────────────────────────────────────────────
  project_name  = "clinical-rag-foundry"  # Project name for tfstate key (e.g., clinical-rag-foundry, sales)
  function_name = "sf-medical-pdf-parser" # Step Function name (without env suffix)
  company_name  = "vigalcontec"           # Company name for resource naming

  # ─────────────────────────────────────────────────────────────────────────────
  # S3 Trigger Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  s3_trigger = {
    enabled = true           # Set to false to disable S3 trigger
    prefix  = "uploads/pdfs" # S3 prefix to monitor for PDF uploads
    suffix  = ".pdf"         # File suffix filter
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Lambda Functions to invoke (read from SSM)
  # Each Lambda must be deployed separately and export its ARN to SSM at:
  #   /{env}/lambda/{function_name}/function_arn
  # ─────────────────────────────────────────────────────────────────────────────
  lambda_functions = [
    # "medical-pdf-parser",  # Add your Lambda function names here
  ]

  # ─────────────────────────────────────────────────────────────────────────────
  # AWS Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  aws_region         = "eu-west-1"
  log_retention_days = 30

  # ─────────────────────────────────────────────────────────────────────────────
  # Computed Values (DO NOT MODIFY)
  # ─────────────────────────────────────────────────────────────────────────────
  account_id   = data.aws_caller_identity.current.account_id
  full_name    = "${local.function_name}-${var.environment}"
  state_bucket = "tfstate-${local.company_name}-${var.environment}-${local.account_id}"

  # Common tags applied to all resources
  common_tags = {
    Project     = local.project_name
    Function    = local.function_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
