# =============================================================================
# SSM Parameter Exports
# =============================================================================
# Export Step Function information to SSM for use by other projects

# -----------------------------------------------------------------------------
# Step Function ARN
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "state_machine_arn" {
  name        = "/${var.environment}/${local.project_name}/stepfunction/${local.function_name}/state_machine_arn"
  description = "Step Function state machine ARN for ${local.full_name}"
  type        = "String"
  value       = aws_sfn_state_machine.main.arn

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Step Function Name
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "state_machine_name" {
  name        = "/${var.environment}/${local.project_name}/stepfunction/${local.function_name}/state_machine_name"
  description = "Step Function state machine name for ${local.full_name}"
  type        = "String"
  value       = aws_sfn_state_machine.main.name

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Step Function Role ARN
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "state_machine_role_arn" {
  name        = "/${var.environment}/${local.project_name}/stepfunction/${local.function_name}/role_arn"
  description = "Step Function execution role ARN for ${local.full_name}"
  type        = "String"
  value       = aws_iam_role.step_function.arn

  tags = local.common_tags
}
