# =============================================================================
# Backend Configuration
# =============================================================================
# Backend is configured via -backend-config flags in CI/CD

terraform {
  backend "s3" {}
}
