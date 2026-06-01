# =============================================================================
# Configuration - Clinical PDF Table Extraction Pipeline
# =============================================================================

locals {
  # ─────────────────────────────────────────────────────────────────────────────
  # Project Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  project_name  = "clinical-rag-foundry"
  function_name = "sf-clinical-pdf-parser"
  company_name  = "vigalcontec"

  # ─────────────────────────────────────────────────────────────────────────────
  # S3 Trigger Configuration - Triggered by _events.json files
  # These are created by the Locator Lambda after analyzing PDFs
  # ─────────────────────────────────────────────────────────────────────────────
  s3_trigger = {
    enabled = true
    prefix  = "crf/clinical_pdfs/"
    suffix  = "_events.json"
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Distributed Map Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  distributed_map = {
    max_concurrency              = 40 # Max parallel Lambda invocations
    tolerated_failure_percentage = 10 # Allow up to 10% failures
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Lambda Functions (read ARNs from SSM)
  # ─────────────────────────────────────────────────────────────────────────────
  lambda_functions = [
    "clinical-pdf-textract-crf",      # Textract Lambda for table extraction
    "clinical-pdf-normalization-crf", # Normalization Lambda (Claude AI)
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
