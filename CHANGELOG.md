# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-05-29

### Added

- **Normalization Lambda** - Added Claude AI normalization step after Textract extraction
- **Chained Processing** - Each table now goes through: Textract → Normalization → S3 (JSONL)
- **Error Handling** - Catch blocks for both Textract and Normalization failures

### Changed

- **Pipeline Flow** - Extended from single Lambda to two-step processing per table
- **Result Selectors** - Added explicit field mapping between Lambda outputs

### SSM Dependencies

| Parameter | Source |
|-----------|--------|
| `/{env}/clinical-rag-foundry/lambda/clinical-pdf-textract-crf/function_arn` | Textract Lambda |
| `/{env}/clinical-rag-foundry/lambda/clinical-pdf-normalization-crf/function_arn` | Normalization Lambda |
| `/{env}/clinical-rag-foundry/dynamodb/clinical-pdf-jobs-crf/table_name` | DynamoDB |
| `/{env}/clinical-rag-foundry/dynamodb/clinical-pdf-jobs-crf/table_arn` | DynamoDB |

---

## [1.0.0] - 2026-05-25

### Added

- **Distributed Map** - Parallel processing of table events (up to 40 concurrent)
- **S3 ItemReader** - Reads `_events.json` directly from S3
- **DynamoDB Integration** - Updates job status on completion
- **Fault Tolerance** - 10% failure threshold before workflow fails
- **Automatic Retry** - 3 retries with exponential backoff for Lambda errors

### Changed

- **Trigger** - Now triggers on `*_events.json` files (not PDFs)
- **State Machine** - Complete rewrite using Distributed Map pattern
- **IAM Policies** - Added S3, DynamoDB, and Distributed Map permissions

### Infrastructure

| Resource | Description |
|----------|-------------|
| Step Function | Distributed Map state machine |
| EventBridge Rule | Triggers on `*_events.json` creation |
| IAM Roles | Step Function (S3, Lambda, DynamoDB), EventBridge |
| CloudWatch Logs | Step Function execution logging |

### SSM Dependencies

| Parameter | Source |
|-----------|--------|
| `/{env}/clinical-rag-foundry/lambda/clinical-pdf-textract-crf/function_arn` | Textract Lambda |
| `/{env}/clinical-rag-foundry/dynamodb/clinical-pdf-jobs-crf/table_name` | DynamoDB |
| `/{env}/clinical-rag-foundry/dynamodb/clinical-pdf-jobs-crf/table_arn` | DynamoDB |

---

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
