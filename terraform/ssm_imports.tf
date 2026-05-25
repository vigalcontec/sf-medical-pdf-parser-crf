# =============================================================================
# SSM Parameter Imports
# =============================================================================
# Import parameters from other projects (datalake, lambda, etc.)

# =============================================================================
# Datalake Configuration (from aws-datalake-layers)
# =============================================================================

# -----------------------------------------------------------------------------
# Raw Layer
# -----------------------------------------------------------------------------
data "aws_ssm_parameter" "raw_bucket_name" {
  name = "/${var.environment}/datalake/raw/bucket_name"
}

data "aws_ssm_parameter" "raw_bucket_arn" {
  name = "/${var.environment}/datalake/raw/bucket_arn"
}

data "aws_ssm_parameter" "raw_kms_key_arn" {
  name = "/${var.environment}/datalake/raw/kms_key_arn"
}

# -----------------------------------------------------------------------------
# Staging Layer
# -----------------------------------------------------------------------------
data "aws_ssm_parameter" "staging_bucket_name" {
  name = "/${var.environment}/datalake/staging/bucket_name"
}

data "aws_ssm_parameter" "staging_bucket_arn" {
  name = "/${var.environment}/datalake/staging/bucket_arn"
}

data "aws_ssm_parameter" "staging_kms_key_arn" {
  name = "/${var.environment}/datalake/staging/kms_key_arn"
}

# -----------------------------------------------------------------------------
# Datalake Locals
# -----------------------------------------------------------------------------
locals {
  datalake = {
    raw = {
      bucket_name = data.aws_ssm_parameter.raw_bucket_name.value
      bucket_arn  = data.aws_ssm_parameter.raw_bucket_arn.value
      kms_key_arn = data.aws_ssm_parameter.raw_kms_key_arn.value
    }
    staging = {
      bucket_name = data.aws_ssm_parameter.staging_bucket_name.value
      bucket_arn  = data.aws_ssm_parameter.staging_bucket_arn.value
      kms_key_arn = data.aws_ssm_parameter.staging_kms_key_arn.value
    }
  }
}

# =============================================================================
# DynamoDB Configuration (from dynamodb-clinical-pdf-jobs-crf)
# =============================================================================
data "aws_ssm_parameter" "dynamodb_table_name" {
  name = "/${var.environment}/${local.project_name}/dynamodb/clinical-pdf-jobs-crf/table_name"
}

data "aws_ssm_parameter" "dynamodb_table_arn" {
  name = "/${var.environment}/${local.project_name}/dynamodb/clinical-pdf-jobs-crf/table_arn"
}

locals {
  dynamodb = {
    clinical_pdf_jobs = {
      table_name = data.aws_ssm_parameter.dynamodb_table_name.value
      table_arn  = data.aws_ssm_parameter.dynamodb_table_arn.value
    }
  }
}

# =============================================================================
# Lambda Function ARNs (from lambda-clinical-pdf-textract-crf)
# =============================================================================
# Each Lambda must export its ARN to SSM at: /{env}/{project}/lambda/{name}/function_arn

data "aws_ssm_parameter" "lambda_arns" {
  for_each = toset(local.lambda_functions)
  name     = "/${var.environment}/${local.project_name}/lambda/${each.value}/function_arn"
}

locals {
  lambda_arns = {
    for name in local.lambda_functions :
    name => data.aws_ssm_parameter.lambda_arns[name].value
  }
}
