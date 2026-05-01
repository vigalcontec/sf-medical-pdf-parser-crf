# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-30

### Added

- **Step Functions State Machine** - Orchestrated workflow with retry/error handling
- **S3 Event Trigger** - EventBridge rule for automatic execution on PDF upload
- **Lambda from SSM** - References external Lambda function via SSM Parameter Store
- **Terraform Infrastructure** - Full IaC for Step Function and EventBridge
- **GitHub Actions CI/CD** - OIDC authentication, multi-environment support
- **X-Ray Tracing** - End-to-end observability

### Infrastructure

| Resource | Description |
|----------|-------------|
| Step Function | State machine invoking Lambda from SSM |
| EventBridge Rule | S3 upload trigger |
| IAM Roles | Step Function, EventBridge |
| CloudWatch Logs | Step Function execution logging |

### SSM Dependencies

The Step Function reads Lambda ARN from:
- `/{env}/lambda/{function_name}/function_arn`
